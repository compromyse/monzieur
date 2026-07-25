require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "belongs to user" do
    assert_equal users(:owner), sessions(:owner_session).user
  end

  test "user is required" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "Test Agent")
    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"
  end

  test "valid with a user, ip_address, and user_agent" do
    session = Session.new(user: users(:owner), ip_address: "127.0.0.1", user_agent: "Test Agent")
    assert session.valid?
  end

  test "ip_address is not required" do
    session = Session.new(user: users(:owner))
    assert session.valid?
  end

  test "user_agent is not required" do
    session = Session.new(user: users(:owner))
    assert session.valid?
  end

  test "can be created and persisted" do
    assert_difference "Session.count", 1 do
      Session.create!(user: users(:staff), ip_address: "10.0.0.1", user_agent: "Another Agent")
    end
  end

  test "destroying the owning user destroys the session" do
    # Use a fresh user with no pantries_user rows — users(:owner) has one
    # (no dependent/cascade defined for that association), which would
    # raise a foreign key violation unrelated to what this test checks.
    user = User.create!(username: "temp_session_destroy2", password: "password")
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")

    assert_difference "Session.count", -1 do
      user.destroy
    end
    assert_not Session.exists?(session.id)
  end

  test "Current.session exposes the associated user via delegation" do
    Current.session = sessions(:owner_session)
    assert_equal users(:owner), Current.user
  end

  test "Current.user is nil when Current.session is not set" do
    assert_nil Current.session
    assert_nil Current.user
  end
end
