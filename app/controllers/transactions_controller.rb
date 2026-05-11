class TransactionsController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: 取引機能は未使用。URL直打ちを含めアクセス不可にする。
  before_action -> { redirect_to requests_path }
  before_action :finalize_overdue_transactions!
  before_action :set_paid_advice_request, only: [:show, :deliver, :complete]
  before_action :authorize_transaction_access!, only: [:show]
  before_action :authorize_trainer!, only: [:deliver]
  before_action :authorize_member!, only: [:complete]

  def index
    @transactions = if current_user.trainer?
                      PaidAdviceRequest.active_for_trainer(current_user.id)
                    else
                      PaidAdviceRequest.active_for_member(current_user.id)
                    end
    @transactions = @transactions.includes(:request, :member, :trainer, :advice)
                                 .order(created_at: :desc)
  end

  def show
    @transaction_delivery_polish_draft_token = "transaction-delivery-#{@paid_advice_request.id}-trainer-#{current_user.id}"
    @remaining_transaction_delivery_polish_attempts = AdvicesController::POLISH_MAX_ATTEMPTS
  end

  def deliver
    unless @paid_advice_request.awaiting_trainer_delivery?
      return redirect_to transaction_path(@paid_advice_request), alert: "この取引はすでに納品済み、または完了しています"
    end

    if [PaidAdviceRequest::STATUS_CHECKOUT_STARTED, PaidAdviceRequest::STATUS_PAID_LEGACY].include?(@paid_advice_request.status) && @paid_advice_request.paid_at.present?
      @paid_advice_request.update_column(:status, PaidAdviceRequest::STATUS_IN_PROGRESS)
    end

    delivery_body = params[:delivery_body].to_s.strip
    delivery_video = params[:delivery_video]
    video_provided = delivery_video.present?

    if delivery_body.blank?
      return redirect_to transaction_path(@paid_advice_request), alert: "詳しいアドバイスのテキストを入力してください"
    end

    if @paid_advice_request.requires_video_delivery? && !video_provided
      return redirect_to transaction_path(@paid_advice_request), alert: "【テキスト＋動画】のメニューです。動画も投稿してください。"
    end

    @paid_advice_request.transaction do
      if @paid_advice_request.requires_video_delivery?
        @paid_advice_request.delivery_video.attach(delivery_video)
      end
      @paid_advice_request.update!(
        delivery_body: delivery_body,
        status: PaidAdviceRequest::STATUS_DELIVERED,
        delivered_at: Time.current
      )
    end

    redirect_to transaction_path(@paid_advice_request), notice: "納品しました"
  end

  def complete
    unless @paid_advice_request.delivered?
      return redirect_to transaction_path(@paid_advice_request), alert: "納品済みの取引のみ完了できます"
    end

    @paid_advice_request.update!(
      status: PaidAdviceRequest::STATUS_COMPLETED,
      completed_at: Time.current
    )
    redirect_to transaction_path(@paid_advice_request), notice: "取引を完了しました"
  end

  private

  def set_paid_advice_request
    @paid_advice_request = PaidAdviceRequest.includes(
      :request,
      :advice,
      :member,
      :trainer,
      { request: [:user, { video_attachment: :blob }, { advices: [:user, { video_attachment: :blob }] }] }
    ).find(params[:id])
  end

  def authorize_transaction_access!
    return if current_user.id == @paid_advice_request.member_id || current_user.id == @paid_advice_request.trainer_id

    redirect_to requests_path, alert: "この取引を表示する権限がありません"
  end

  def authorize_trainer!
    return if current_user.id == @paid_advice_request.trainer_id

    redirect_to transaction_path(@paid_advice_request), alert: "納品できるのは担当トレーナーのみです"
  end

  def authorize_member!
    return if current_user.id == @paid_advice_request.member_id

    redirect_to transaction_path(@paid_advice_request), alert: "完了できるのは依頼したメンバーのみです"
  end

  def finalize_overdue_transactions!
    PaidAdviceRequest.finalize_overdue_delivered!
  end
end
