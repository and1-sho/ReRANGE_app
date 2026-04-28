class PaidAdviceRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_request_and_advice
  before_action :ensure_request_owner_member!

  def create
    menu_code = params[:menu_code].to_s
    unless @advice.accepts_paid_advice_enabled? && @advice.paid_menu_available?(menu_code)
      return redirect_to request_path(@request), alert: "選択された有料メニューは現在受け付けていません"
    end

    amount_jpy = @advice.paid_menu_price_jpy(menu_code)
    if amount_jpy.blank?
      return redirect_to request_path(@request), alert: "金額の取得に失敗しました。もう一度お試しください"
    end

    if PaidAdviceRequest.where(request: @request, member: current_user)
                        .where(status: [PaidAdviceRequest::STATUS_IN_PROGRESS, PaidAdviceRequest::STATUS_DELIVERED, PaidAdviceRequest::STATUS_COMPLETED])
                        .exists?
      return redirect_to request_path(@request), alert: "このリクエストの取引はすでに作成されています"
    end

    if ENV["STRIPE_SECRET_KEY"].blank?
      return redirect_to request_path(@request), alert: "決済設定が未完了です（STRIPE_SECRET_KEY）"
    end

    paid_request = PaidAdviceRequest.create!(
      advice: @advice,
      request: @request,
      member: current_user,
      trainer: @advice.user,
      menu_code: menu_code,
      amount_jpy: amount_jpy
    )

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "jpy",
            product_data: {
              name: "#{@advice.user.name}への詳しいアドバイス依頼",
              description: @advice.paid_menu_label(menu_code)
            },
            unit_amount: amount_jpy
          },
          quantity: 1
        }
      ],
      metadata: {
        paid_advice_request_id: paid_request.id,
        request_id: @request.id,
        advice_id: @advice.id
      },
      # Stripe はリテラル {CHECKOUT_SESSION_ID} を置換する。Rails の url ヘルパに渡すと {} がエンコードされ置換されない。
      success_url: stripe_checkout_success_url,
      cancel_url: paid_advice_requests_cancel_url(request_id: @request.id, advice_id: @advice.id)
    )

    paid_request.update!(stripe_checkout_session_id: session.id)
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    redirect_to request_path(@request), alert: "決済ページの作成に失敗しました: #{e.message}"
  end

  def success
    session_id = params[:session_id].to_s
    paid_request = PaidAdviceRequest.find_by(stripe_checkout_session_id: session_id)
    return redirect_to request_path(@request), alert: "決済セッションが見つかりません" if paid_request.blank?

    if ENV["STRIPE_SECRET_KEY"].present?
      checkout = Stripe::Checkout::Session.retrieve(session_id)
      if checkout.payment_status == "paid"
        paid_request.update!(
          status: PaidAdviceRequest::STATUS_IN_PROGRESS,
          stripe_payment_intent_id: checkout.payment_intent.to_s,
          paid_at: Time.current
        )
      end
    end

    redirect_to request_path(@request), notice: "詳しいアドバイス依頼の決済が完了しました"
  rescue Stripe::StripeError => e
    redirect_to request_path(@request), alert: "決済確認に失敗しました: #{e.message}"
  end

  def cancel
    redirect_to request_path(@request), alert: "決済はキャンセルされました"
  end

  private

  def set_request_and_advice
    @request = Request.find(params[:request_id])
    @advice = @request.advices.find(params[:advice_id])
  end

  def ensure_request_owner_member!
    return if current_user.member? && @request.user_id == current_user.id

    redirect_to request_path(@request), alert: "この決済を実行する権限がありません"
  end

  def stripe_checkout_success_url
    base = paid_advice_requests_success_url(request_id: @request.id, advice_id: @advice.id)
    sep = base.include?("?") ? "&" : "?"
    "#{base}#{sep}session_id={CHECKOUT_SESSION_ID}"
  end
end
