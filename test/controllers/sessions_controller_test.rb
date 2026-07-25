require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the login form when logged out" do
    get new_session_path
    assert_response :success
  end

  test "new still renders when already logged in" do
    sign_in_as(users(:owner))
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials logs the user in and redirects to root" do
    assert_difference("Session.count", 1) do
      post session_path, params: { username: users(:owner).username, password: "password" }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "create sets a signed session_id cookie that authenticates subsequent requests" do
    post session_path, params: { username: users(:owner).username, password: "password" }
    assert cookies[:session_id].present?

    # A subsequent request in this same test run (same cookie jar) should now
    # be treated as authenticated instead of being bounced to the login page.
    get root_path
    assert_response :success
  end

  test "create with wrong password does not log the user in" do
    assert_no_difference("Session.count") do
      post session_path, params: { username: users(:owner).username, password: "wrong-password" }
    end
    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]

    # Confirm we're really not authenticated: hitting a protected page bounces
    # back to login instead of succeeding.
    get pantry_users_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "create with unknown username does not log the user in" do
    assert_no_difference("Session.count") do
      post session_path, params: { username: "does-not-exist", password: "password" }
    end
    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "unauthenticated access to a protected page redirects to login, then returns there after signing in" do
    protected_url = pantry_users_path(pantry_id: pantries(:main).id)

    get protected_url
    assert_redirected_to new_session_path

    post session_path, params: { username: users(:owner).username, password: "password" }
    assert_redirected_to protected_url
  end

  test "destroy logs the user out and requires status see_other" do
    sign_in_as(users(:owner))

    assert_difference("Session.count", -1) do
      delete session_path
    end
    assert_redirected_to new_session_path
    assert_response :see_other

    # Logged out for real now: a protected page bounces back to login.
    get pantry_users_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "destroy while logged out redirects to login without raising" do
    assert_no_difference("Session.count") do
      delete session_path
    end
    assert_redirected_to new_session_path
  end
end
