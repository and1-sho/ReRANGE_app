class TransactionsController < ApplicationController
  before_action :authenticate_user!
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
  end

  def deliver
    unless @paid_advice_request.in_progress?
      return redirect_to transaction_path(@paid_advice_request), alert: "この取引はすでに納品済み、または完了しています"
    end

    delivery_body = params[:delivery_body].to_s.strip
    delivery_video = params[:delivery_video]

    if delivery_body.blank?
      return redirect_to transaction_path(@paid_advice_request), alert: "納品テキストを入力してください"
    end

    if @paid_advice_request.requires_video_delivery? && delivery_video.blank?
      return redirect_to transaction_path(@paid_advice_request), alert: "このメニューは動画の納品が必須です"
    end

    @paid_advice_request.transaction do
      @paid_advice_request.delivery_video.attach(delivery_video) if delivery_video.present?
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
