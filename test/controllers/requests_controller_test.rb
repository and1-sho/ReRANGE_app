require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  test "未ログインで一覧にアクセスするとログイン画面へリダイレクトされる" do
    get requests_path
    assert_redirected_to new_user_session_path
  end

  test "未ログインで詳細にアクセスするとログイン画面へリダイレクトされる" do
    get request_path(requests(:one))
    assert_redirected_to new_user_session_path
  end
end
