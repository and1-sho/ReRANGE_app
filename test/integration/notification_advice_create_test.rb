require "test_helper"
require "securerandom"

class NotificationAdviceCreateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @member = User.create!(
      name: "member user",
      email: "member_notify_#{SecureRandom.hex(4)}@example.test",
      role: :member,
      password: "password123",
      password_confirmation: "password123"
    )

    @coach = User.create!(
      name: "coach user",
      email: "coach_notify_#{SecureRandom.hex(4)}@example.test",
      role: :coach,
      password: "password123",
      password_confirmation: "password123"
    )

    @coach2 = User.create!(
      name: "coach user 2",
      email: "coach_notify_#{SecureRandom.hex(4)}@example.test",
      role: :coach,
      password: "password123",
      password_confirmation: "password123"
    )

    @target_request = Request.create!(
      user: @member,
      title: "通知テストの相談",
      body: "フォームの確認をしたいです"
    )
  end

  test "coachがadviceを投稿するとmemberに通知が1件作成される" do
    sign_in @coach

    assert_difference("Notification.count", 1) do
      post request_advice_path(@target_request), params: {
        advice: {
          body: "通知が届くかのテストです"
        }
      }
    end

    notification = Notification.order(:created_at).last
    assert_equal @member.id, notification.user_id
    assert_equal @target_request.id, notification.request_id
    assert_equal "advice_received", notification.kind
    assert_equal "「#{@target_request.title}」にアドバイスが届きました", notification.message
  end

  test "memberが新規相談を投稿すると全coachに通知が作成される" do
    sign_in @member

    assert_difference("Notification.where(kind: 'new_request').count", User.coach.count) do
      post requests_path, params: {
        request: {
          title: "新規相談通知テスト",
          body: "コーチ全員に通知が行くか確認します"
        }
      }
    end

    created_request = Request.order(:created_at).last
    coach_ids = Notification.where(kind: "new_request", request_id: created_request.id).pluck(:user_id).sort
    assert_equal User.coach.order(:id).pluck(:id), coach_ids
  end

  test "memberが本文を更新したときだけアドバイス担当coachに通知される" do
    Advice.create!(
      request: @target_request,
      user: @coach,
      body: "最初のアドバイス"
    )

    sign_in @member

    assert_no_difference("Notification.where(kind: 'request_body_updated').count") do
      patch request_path(@target_request), params: {
        request: {
          title: "タイトルだけ変更",
          body: @target_request.body
        }
      }
    end

    assert_difference("Notification.where(kind: 'request_body_updated').count", 1) do
      patch request_path(@target_request), params: {
        request: {
          title: "タイトルだけ変更",
          body: "本文を更新しました"
        }
      }
    end

    notification = Notification.where(kind: "request_body_updated").order(:created_at).last
    assert_equal @coach.id, notification.user_id
    assert_equal @target_request.id, notification.request_id
  end

  test "相談詳細を開くと既読になりベルバッジは9件以上で9+表示になる" do
    sign_in @coach

    10.times do |i|
      Notification.create!(
        user: @coach,
        request: @target_request,
        kind: "new_request",
        message: "通知#{i + 1}"
      )
    end

    get requests_path
    assert_select ".notification-bell-link__badge", text: "9+"

    unread_notification = @coach.notifications.unread.order(:created_at).first
    get request_path(@target_request)
    unread_notification.reload
    assert_not_nil unread_notification.read_at
  end
end
