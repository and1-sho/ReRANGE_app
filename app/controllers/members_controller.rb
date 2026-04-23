class MembersController < ApplicationController
  before_action :authenticate_user!, only: [:edit, :update]
  before_action :set_member
  before_action :authorize_member_owner!, only: [:edit, :update]

  # プロフィール閲覧（公開）
  def show
    @member_requests = member_profile_requests
    @member_request_feed_empty_copy =
      if user_signed_in? && current_user == @member
        "まだリクエストを投稿していません"
      else
        "表示できる公開リクエストはまだありません"
      end
  end

  def edit
  end

  def update
    handle_image_removal_on_update!

    if @member.update(member_profile_params)
      redirect_to member_path(@member), notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # 本人閲覧時は指定トレーナー宛も含む。それ以外は公開フィード相当のみ。
  def member_profile_requests
    rel = @member.requests
                 .includes(:user, video_attachment: :blob, video_thumbnail_attachment: :blob)
                 .order(created_at: :desc)
    if user_signed_in? && current_user == @member
      rel
    else
      rel.on_public_feed
    end
  end

  def set_member
    @member = User.member.find_by(slug: params[:slug])
    return if @member.present?

    @member = User.member.find_by!(id: params[:slug]) if params[:slug].to_s.match?(/\A\d+\z/)
  end

  def authorize_member_owner!
    return if current_user == @member

    redirect_to member_path(@member), alert: "このプロフィールを編集する権限がありません"
  end

  def member_profile_params
    params.require(:user).permit(
      :profile_affiliation,
      :profile_prefecture,
      :boxing_started_on,
      :birth_date,
      :stance,
      :weight_class,
      :profile_bio,
      :avatar_image,
      :header_image
    )
  end

  def handle_image_removal_on_update!
    if params.dig(:user, :remove_avatar_image) == "1" && params.dig(:user, :avatar_image).blank?
      @member.avatar_image.purge if @member.avatar_image.attached?
    end

    if params.dig(:user, :remove_header_image) == "1" && params.dig(:user, :header_image).blank?
      @member.header_image.purge if @member.header_image.attached?
    end
  end
end
