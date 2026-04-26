require "test_helper"

class AdvicesControllerTest < ActionDispatch::IntegrationTest
  test "未ログインでadvice新規にアクセスするとログイン画面へリダイレクトされる" do
    get new_request_advice_path(requests(:one))
    assert_redirected_to new_user_session_path
  end

  test "未ログインでadvice作成するとログイン画面へリダイレクトされる" do
    post request_advices_path(requests(:one)), params: { advice: { body: "test" } }
    assert_redirected_to new_user_session_path
  end
end
