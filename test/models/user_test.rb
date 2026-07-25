require "test_helper"

class UserTest < ActiveSupport::TestCase
  # --- has_secure_password ---

  test "authenticates with correct password" do
    assert users(:owner).authenticate("password")
  end

  test "does not authenticate with incorrect password" do
    assert_not users(:owner).authenticate("wrong_password")
  end

  test "password is required on create (has_secure_password)" do
    u = User.new(username: "nodigest")
    assert_not u.valid?
    assert_includes u.errors[:password], "can't be blank"
  end

  test "password confirmation mismatch is invalid" do
    u = User.new(username: "mismatch", password: "password", password_confirmation: "different")
    assert_not u.valid?
    assert_includes u.errors[:password_confirmation], "doesn't match Password"
  end

  # --- username normalization ---

  test "normalizes username by stripping whitespace and downcasing on assignment" do
    u = User.new(username: "  MixedCase  ")
    assert_equal "mixedcase", u.username
  end

  test "normalization does not retroactively affect already-loaded fixture data" do
    # Fixture usernames are already lowercase with no whitespace, so this is mostly
    # documenting that normalizes only fires on assignment, not on load.
    assert_equal "owner", users(:owner).username
  end

  # --- uniqueness relies on DB constraint, not a validation ---

  test "there is no ActiveRecord uniqueness validation on username" do
    validators = User.validators_on(:username).map(&:class)
    assert_not_includes validators, ActiveRecord::Validations::UniquenessValidator
  end

  test "duplicate username raises RecordNotUnique at the DB level rather than failing validation" do
    dup = User.new(username: "owner", password: "password")
    assert dup.valid?, "model-level validation does not catch the duplicate (no uniqueness validator)"
    assert_raises(ActiveRecord::RecordNotUnique) do
      dup.save
    end
  end

  # --- username required at the DB level ---

  test "username is required at the database level" do
    u = User.new(password: "password")
    u.password_digest = BCrypt::Password.create("password", cost: 4)
    assert_raises(ActiveRecord::NotNullViolation) do
      u.save(validate: false)
    end
  end

  # --- site_admin ---

  test "site_admin defaults to false" do
    u = User.create!(username: "freshuser", password: "password")
    assert_equal false, u.site_admin
  end

  test "site_admin_user fixture is a site admin" do
    assert users(:site_admin_user).site_admin?
  end

  # --- associations ---

  test "has_many sessions" do
    assert_respond_to users(:owner), :sessions
    assert_includes users(:owner).sessions, sessions(:owner_session)
  end

  test "destroying a user destroys its sessions" do
    # Use a fresh user with no pantries_user rows — users(:owner) has one
    # (no dependent/cascade defined for that association), which would
    # raise a foreign key violation unrelated to what this test checks.
    user = User.create!(username: "temp_session_destroy", password: "password")
    user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")

    assert_difference "Session.count", -1 do
      user.destroy
    end
  end

  test "has_many pantries_user" do
    assert_respond_to users(:owner), :pantries_user
    assert_includes users(:owner).pantries_user, pantries_users(:owner_main)
  end

  test "has_many pantries through pantries_user" do
    Current.session = sessions(:owner_session)
    assert_includes users(:owner).pantries, pantries(:main)
  end

  test "no_pantry_user has no pantries_user rows" do
    assert_empty users(:no_pantry_user).pantries_user
  end

  test "no_pantry_user has no pantries" do
    Current.session = Session.new(user: users(:no_pantry_user))
    assert_empty users(:no_pantry_user).pantries
  end

  test "has_many visits" do
    Current.pantry = pantries(:main)
    assert_respond_to users(:staff), :visits
    assert_includes users(:staff).visits, visits(:jane_visit_today)
  end

  # --- owner?/admin? read Current.pantries_user ---

  test "owner? is true when Current.pantries_user has owner role" do
    Current.pantries_user = pantries_users(:owner_main)
    assert users(:owner).owner?
  end

  test "owner? is false when Current.pantries_user has admin role" do
    Current.pantries_user = pantries_users(:admin_main)
    assert_not users(:admin).owner?
  end

  test "owner? is false when Current.pantries_user has staff role" do
    Current.pantries_user = pantries_users(:staff_main)
    assert_not users(:staff).owner?
  end

  test "admin? is true when Current.pantries_user has admin role" do
    Current.pantries_user = pantries_users(:admin_main)
    assert users(:admin).admin?
  end

  test "admin? is true when Current.pantries_user has owner role (owner counts as admin)" do
    Current.pantries_user = pantries_users(:owner_main)
    assert users(:owner).admin?
  end

  test "admin? is false when Current.pantries_user has staff role" do
    Current.pantries_user = pantries_users(:staff_main)
    assert_not users(:staff).admin?
  end

  test "owner? raises NoMethodError when Current.pantries_user is nil" do
    Current.pantries_user = nil
    assert_raises(NoMethodError) do
      users(:owner).owner?
    end
  end

  test "admin? raises NoMethodError when Current.pantries_user is nil" do
    Current.pantries_user = nil
    assert_raises(NoMethodError) do
      users(:admin).admin?
    end
  end
end
