require "test_helper"
require "securerandom"

class RequestPolishTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @member = User.create!(
      name: "member user",
      email: "member_polish_#{SecureRandom.hex(4)}@example.test",
      role: :member,
      password: "password123",
      password_confirmation: "password123"
    )

    @trainer = User.create!(
      name: "trainer user",
      email: "trainer_polish_#{SecureRandom.hex(4)}@example.test",
      role: :trainer,
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "member can polish request body" do
    sign_in @member
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ title: "パンチ力向上について", body: "パンチ力を上げるための練習方法を教えてください。" })

    original_new = RequestTextPolisher.method(:new)
    RequestTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      post polish_requests_path, params: { body: "パンチ力上げたい 何したらいい?", draft_token: "draft-1" }, as: :json
    ensure
      RequestTextPolisher.define_singleton_method(:new, original_new)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "パンチ力向上について", json["title"]
    assert_equal "パンチ力を上げるための練習方法を教えてください。", json["body"]
  end

  test "returns error when body is blank" do
    sign_in @member

    post polish_requests_path, params: { body: "   ", draft_token: "draft-1" }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "本文を入力してください", json["error"]
  end

  test "polish is limited to two attempts within same draft" do
    sign_in @member
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ title: "ガード改善について", body: "ガード時の下がり癖を改善したいです。" })

    original_new = RequestTextPolisher.method(:new)
    RequestTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      token = "same-draft"
      post polish_requests_path, params: { body: "1回目の整形です", draft_token: token }, as: :json
      assert_response :success
      assert_equal 1, JSON.parse(response.body)["remaining_attempts"]

      get new_request_path
      assert_response :success
      assert_match "残り <span data-request-polish-target=\"attempts\">2</span> 回", response.body

      post polish_requests_path, params: { body: "2回目の整形です", draft_token: token }, as: :json
      assert_response :success
      assert_equal 0, JSON.parse(response.body)["remaining_attempts"]

      post polish_requests_path, params: { body: "3回目は失敗するはず", draft_token: token }, as: :json
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      assert_equal "文章を整える操作は2回までです", json["error"]
      assert_equal 0, json["remaining_attempts"]
    ensure
      RequestTextPolisher.define_singleton_method(:new, original_new)
    end
  end

  test "trainer cannot use polish endpoint" do
    sign_in @trainer

    post polish_requests_path, params: { body: "整形したい", draft_token: "draft-1" }, as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "メンバーのみリクエストを作成できます", json["error"]
  end

  test "different draft token has independent limit" do
    sign_in @member
    fake_polisher = Struct.new(:result) do
      def call
        result
      end
    end.new({ title: "ジャブ改善について", body: "ジャブの改善点を教えてください。" })

    original_new = RequestTextPolisher.method(:new)
    RequestTextPolisher.define_singleton_method(:new) { |**_kwargs| fake_polisher }
    begin
      token1 = "draft-a"
      token2 = "draft-b"

      2.times do |i|
        post polish_requests_path, params: { body: "token1-#{i}", draft_token: token1 }, as: :json
        assert_response :success
      end

      post polish_requests_path, params: { body: "token1-limit", draft_token: token1 }, as: :json
      assert_response :unprocessable_entity

      post polish_requests_path, params: { body: "token2-first", draft_token: token2 }, as: :json
      assert_response :success
      assert_equal 1, JSON.parse(response.body)["remaining_attempts"]
    ensure
      RequestTextPolisher.define_singleton_method(:new, original_new)
    end
  end

end
