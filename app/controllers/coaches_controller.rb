class CoachesController < ApplicationController
  before_action :authenticate_user!, only: [:edit, :update]
  before_action :set_coach, only: [:show, :edit, :update]
  before_action :authorize_coach_owner!, only: [:edit, :update]

  def index
    @sort = params[:sort] == "all" ? "all" : "new"
    @coaches = User.coach
    @coaches = if @sort == "all"
                 @coaches.order(:name, :id)
               else
                 @coaches.order(created_at: :desc)
               end
  end

  # プロフィール閲覧は公開（未ログインでもアクセス可）
  def show
  end

  # コーチ本人がプロフィール編集
  def edit
  end

  def update
    # 新しい画像が選ばれていない時だけ、削除チェックに従って purge する
    handle_image_removal_on_update!

    if @coach.update(coach_profile_params)
      redirect_to coach_path(@coach), notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_coach
    # 基本は slug で検索。既存データで slug が未設定の場合のみ id も許可する
    @coach = User.coach.find_by(slug: params[:slug])
    return if @coach.present?

    @coach = User.coach.find_by!(id: params[:slug]) if params[:slug].to_s.match?(/\A\d+\z/)
  end

  def authorize_coach_owner!
    return if current_user == @coach

    redirect_to coach_path(@coach), alert: "このプロフィールを編集する権限がありません"
  end

  def coach_profile_params
    params.require(:user).permit(
      :profile_affiliation,
      :profile_prefecture,
      :profile_area_detail,
      :boxing_started_on,
      :coaching_started_on,
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
      @coach.avatar_image.purge if @coach.avatar_image.attached?
    end

    if params.dig(:user, :remove_header_image) == "1" && params.dig(:user, :header_image).blank?
      @coach.header_image.purge if @coach.header_image.attached?
    end
  end
end
