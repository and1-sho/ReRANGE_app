require "test_helper"

class AdvicesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get advices_new_url
    assert_response :success
  end

  test "should get create" do
    get advices_create_url
    assert_response :success
  end
end
