require "test_helper"
require "securerandom"

class AdvicePolishTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @member = User.create!(
      name: "member user",
      email: "member_advice_polish_#{SecureRandom.hex(4)}@example.test",
      role: :member,
      password: "password123",
      password_confirmation: "password123"
    )

    @trainer = User.create!(
      name: "trainer user",
      email: "trainer_advice_polish_#{SecureRandom.hex(4)}@example.test",
      role: :trainer,
      password: "password123",
      password_confirmation: "password123"
    )

    @other_trainer = User.create!(
      name: "other trainer",
      email: "trainer2_advice_polish_#{SecureRandom.hex(4)}@example.test",
      role: :trainer,
      password: "password123",
      password_confirmation: "password123"
    )

    @open_request = Request.create!(
      user: @member,
      title: "アドバイス整形テスト",
      body: "リクエスト本文です"
    )
  end

  test "trainer can polish advice body" do
    sign_in @trainer
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ body: "丁寧に整えたアドバイス本文です。" })

    original_new = AdviceTextPolisher.method(:new)
    AdviceTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      post polish_request_advices_path(@open_request), params: { body: "下書きが荒いです 直して", draft_token: "adv-draft-1" }, as: :json
    ensure
      AdviceTextPolisher.define_singleton_method(:new, original_new)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "丁寧に整えたアドバイス本文です。", json["body"]
    assert_nil json["title"]
    assert_equal 1, json["remaining_attempts"]
  end

  test "member cannot use advice polish endpoint" do
    sign_in @member

    post polish_request_advices_path(@open_request), params: { body: "十分な長さの本文です", draft_token: "draft-1" }, as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "トレーナーのみアドバイスできます", json["error"]
  end

  test "polish is limited to two attempts within same draft" do
    sign_in @trainer
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ body: "整形結果の本文です。" })

    original_new = AdviceTextPolisher.method(:new)
    AdviceTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      token = "adv-same-draft"
      post polish_request_advices_path(@open_request), params: { body: "1回目の整形です十分な長さ", draft_token: token }, as: :json
      assert_response :success
      assert_equal 1, JSON.parse(response.body)["remaining_attempts"]

      post polish_request_advices_path(@open_request), params: { body: "2回目の整形です十分な長さ", draft_token: token }, as: :json
      assert_response :success
      assert_equal 0, JSON.parse(response.body)["remaining_attempts"]

      post polish_request_advices_path(@open_request), params: { body: "3回目は失敗するはず十分な長さ", draft_token: token }, as: :json
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      assert_equal "文章を整える操作は2回までです", json["error"]
      assert_equal 0, json["remaining_attempts"]
    ensure
      AdviceTextPolisher.define_singleton_method(:new, original_new)
    end
  end

  test "designated trainer only can polish for direct request without advice" do
    direct = Request.create!(
      user: @member,
      title: "指定トレーナー宛",
      body: "内容です",
      directed_to_trainer: @other_trainer
    )

    sign_in @trainer
    post polish_request_advices_path(direct), params: { body: "十分な長さの本文です", draft_token: "d-1" }, as: :json
    assert_response :forbidden

    sign_in @other_trainer
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ body: "整形済みです。" })

    original_new = AdviceTextPolisher.method(:new)
    AdviceTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      post polish_request_advices_path(direct), params: { body: "十分な長さの本文です", draft_token: "d-2" }, as: :json
      assert_response :success
    ensure
      AdviceTextPolisher.define_singleton_method(:new, original_new)
    end
  end

  test "advice owner can polish on edit" do
    Advice.create!(request: @open_request, user: @trainer, body: "既存のアドバイス")

    sign_in @trainer
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ body: "更新用に整えた本文です。" })

    original_new = AdviceTextPolisher.method(:new)
    AdviceTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      post polish_request_advices_path(@open_request), params: { body: "編集中下書きで十分な長さ", draft_token: "edit-draft" }, as: :json
    ensure
      AdviceTextPolisher.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_equal "更新用に整えた本文です。", JSON.parse(response.body)["body"]
  end

  test "non-owner cannot polish existing advice" do
    Advice.create!(request: @open_request, user: @trainer, body: "既存のアドバイス")

    sign_in @other_trainer
    post polish_request_advices_path(@open_request), params: { body: "奪おうとする十分な長さの本文", draft_token: "x" }, as: :json
    assert_response :forbidden
  end
end
