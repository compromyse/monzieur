require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "new renders the signup form when logged out" do
    get new_user_path
    assert_response :success
  end

  test "create with valid params signs up a new user, logs them in, and redirects to root" do
    assert_difference("User.count", 1) do
      assert_difference("Session.count", 1) do
        post user_path, params: { username: "brand_new_user", password: "password" }
      end
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    # The password was hashed correctly and can be used to log in again.
    delete session_path
    new_user = User.find_by(username: "brand_new_user")
    sign_in_as(new_user)
    assert_redirected_to root_path
  end

  test "create with a duplicate username raises at the DB level instead of failing gracefully" do
    # User has no `validates :username, uniqueness:` — only a DB-level unique
    # index (see db/schema.rb: index_users_on_username, unique: true). So
    # user.save doesn't return false here, it raises.
    assert_no_difference("User.count") do
      assert_raises(ActiveRecord::RecordNotUnique) do
        post user_path, params: { username: users(:owner).username, password: "password" }
      end
    end
  end

  test "create with a blank password fails validation gracefully" do
    assert_no_difference("User.count") do
      post user_path, params: { username: "someone_new", password: "" }
    end
    assert_redirected_to new_user_path
    assert_equal "Error creating user, maybe the username is taken?", flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "create with a missing password param fails validation gracefully" do
    assert_no_difference("User.count") do
      post user_path, params: { username: "someone_else_new" }
    end
    assert_redirected_to new_user_path
    assert_equal "Error creating user, maybe the username is taken?", flash[:alert]
  end
end
