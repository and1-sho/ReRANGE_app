class ApplicationController < ActionController::Base
  # deviseに追加でカラムを許可する設定
  before_action :configure_permitted_parameters, if: :devise_controller?
    protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
    end
end
