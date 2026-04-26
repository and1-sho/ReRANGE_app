class TrainersController < ApplicationController
  before_action :authenticate_user!, only: [:edit, :update]
  before_action :set_trainer, only: [:show, :edit, :update]
  before_action :authorize_trainer_owner!, only: [:edit, :update]

  def index
    @sort = params[:sort] == "all" ? "all" : "new"
    @trainers = User.trainer
    @trainers = if @sort == "all"
                  @trainers.order(:name, :id)
                else
                  @trainers.order(created_at: :desc)
                end
  end

  # プロフィール閲覧は公開（未ログインでもアクセス可）
  def show
    @trainer_advised_requests = trainer_profile_advised_requests
    @trainer_advised_feed_empty_subcopy = "公開リクエストへアドバイスすると、ここに表示されます。"
  end

  # トレーナー本人がプロフィール編集
  def edit
  end

  def update
    # 新しい画像が選ばれていない時だけ、削除チェックに従って purge する
    handle_image_removal_on_update!

    if @trainer.update(trainer_profile_params)
      redirect_to trainer_path(@trainer), notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # トレーナープロフィールには公開リクエストへのアドバイスのみ表示する。
  def trainer_profile_advised_requests
    rel = Request.joins(:advices)
                 .where(advices: { user_id: @trainer.id })
                 .includes(:user, :advices, video_attachment: :blob, video_thumbnail_attachment: :blob)
                 .distinct
                 .order(created_at: :desc)
    rel.merge(Request.on_public_feed)
  end

  def set_trainer
    # 基本は slug で検索。既存データで slug が未設定の場合のみ id も許可する
    @trainer = User.trainer.find_by(slug: params[:slug])
    return if @trainer.present?

    @trainer = User.trainer.find_by!(id: params[:slug]) if params[:slug].to_s.match?(/\A\d+\z/)
  end

  def authorize_trainer_owner!
    return if current_user == @trainer

    redirect_to trainer_path(@trainer), alert: "このプロフィールを編集する権限がありません"
  end

  def trainer_profile_params
    params.require(:user).permit(
      :profile_affiliation,
      :profile_prefecture,
      :profile_area_detail,
      :boxing_started_on,
      :instruction_started_on,
      :profile_bio,
      :radar_attack,
      :radar_technique,
      :radar_physical,
      :radar_speed,
      :radar_strategy,
      :radar_defense,
      :avatar_image,
      :header_image
    )
  end

  def handle_image_removal_on_update!
    if params.dig(:user, :remove_avatar_image) == "1" && params.dig(:user, :avatar_image).blank?
      @trainer.avatar_image.purge if @trainer.avatar_image.attached?
    end

    if params.dig(:user, :remove_header_image) == "1" && params.dig(:user, :header_image).blank?
      @trainer.header_image.purge if @trainer.header_image.attached?
    end
  end
end
