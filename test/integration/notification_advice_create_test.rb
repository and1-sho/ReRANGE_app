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

    @trainer = User.create!(
      name: "trainer user",
      email: "trainer_notify_#{SecureRandom.hex(4)}@example.test",
      role: :trainer,
      password: "password123",
      password_confirmation: "password123"
    )

    @target_request = Request.create!(
      user: @member,
      title: "通知テストのリクエスト",
      body: "フォームの確認をしたいです"
    )
  end

  test "trainerがadviceを投稿するとmemberに通知が1件作成される" do
    sign_in @trainer

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

  test "memberが新規リクエストを投稿すると全trainerに通知が作成される" do
    sign_in @member

    assert_difference("Notification.where(kind: 'new_request').count", User.trainer.count) do
      post requests_path, params: {
        request: {
          title: "新規リクエスト通知テスト",
          body: "トレーナー全員に通知が行くか確認します"
        }
      }
    end

    created_request = Request.order(:created_at).last
    trainer_ids = Notification.where(kind: "new_request", request_id: created_request.id).pluck(:user_id).sort
    assert_equal User.trainer.order(:id).pluck(:id), trainer_ids
  end

  test "memberが本文を更新したときだけアドバイス担当trainerに通知される" do
    Advice.create!(
      request: @target_request,
      user: @trainer,
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
    assert_equal @trainer.id, notification.user_id
    assert_equal @target_request.id, notification.request_id
  end

  test "リクエスト詳細を開くと既読になりベルバッジは9件以上で9+表示になる" do
    sign_in @trainer

    10.times do |i|
      Notification.create!(
        user: @trainer,
        request: @target_request,
        kind: "new_request",
        message: "通知#{i + 1}"
      )
    end

    get requests_path
    assert_select ".notification-bell-link__badge", text: "9+"

    unread_notification = @trainer.notifications.unread.order(:created_at).first
    get request_path(@target_request)
    unread_notification.reload
    assert_not_nil unread_notification.read_at
  end

  test "memberがトレーナー宛てリクエストを投稿するとそのトレーナーにだけ通知が1件できる" do
    sign_in @member

    assert_difference("Notification.where(kind: 'direct_request').count", 1) do
      post requests_path, params: {
        request: {
          title: "トレーナー宛てテスト",
          body: "一覧には出さないリクエストです",
          directed_to_trainer_id: @trainer.id
        }
      }
    end

    n = Notification.where(kind: "direct_request").order(:created_at).last
    assert_equal @trainer.id, n.user_id
    assert_equal "あなた宛のリクエスト「トレーナー宛てテスト」が届きました", n.message
  end
end
