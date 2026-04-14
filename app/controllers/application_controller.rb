class ApplicationController < ActionController::Base
  # deviseに追加でカラムを許可する設定
  before_action :configure_permitted_parameters, if: :devise_controller?
  # ログイン中ユーザーの「最終訪問日時」を更新する
  before_action :update_last_seen_at, if: :user_signed_in?
  helper_method :app_home_path

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
  end

  # ロゴクリック時の遷移先（ログイン中は一覧、未ログインはトップ）
  def app_home_path
    user_signed_in? ? requests_path : root_path
  end

  # ログイン直後はトップではなく一覧へ遷移
  def after_sign_in_path_for(_resource)
    requests_path
  end

  private

  def update_last_seen_at
    # 毎リクエスト更新だと重いので 5 分以内の再更新はスキップ
    return if current_user.last_seen_at.present? && current_user.last_seen_at > 5.minutes.ago

    # バリデーションを通さず時刻のみ更新
    current_user.update_column(:last_seen_at, Time.current)
  end
end
