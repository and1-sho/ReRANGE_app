module ApplicationHelper
  def user_role_display_label(user)
    case user.role
    when "member" then "メンバー"
    when "trainer" then "トレーナー"
    else user.role.to_s
    end
  end
end
