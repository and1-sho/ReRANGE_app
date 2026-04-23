module ApplicationHelper
  # Twitter 風の相対時刻（日本語）。ホバー用は social_time_title
  def social_time_ago(time)
    return "" if time.blank?

    t = time.in_time_zone
    now = Time.current
    diff = now - t
    return t.strftime("%Y/%m/%d %H:%M") if diff.negative?

    if diff < 60
      "たった今"
    elsif diff < 3600
      "#{(diff / 60).to_i}分前"
    elsif diff < 86_400
      "#{(diff / 3600).to_i}時間前"
    else
      days = (diff / 86_400).floor
      if days < 7
        "#{days}日前"
      elsif days < 30
        w = (days / 7).floor
        w = 1 if w < 1
        "#{w}週間前"
      else
        t.strftime("%Y/%m/%d")
      end
    end
  end

  def social_time_title(time)
    time.in_time_zone.strftime("%Y/%m/%d %H:%M")
  end

  def user_role_display_label(user)
    case user.role
    when "member" then "メンバー"
    when "trainer" then "トレーナー"
    else user.role.to_s
    end
  end
end
