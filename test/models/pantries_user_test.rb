require "test_helper"

class PantriesUserTest < ActiveSupport::TestCase
  # --- associations ---

  test "belongs to user" do
    assert_equal users(:owner), pantries_users(:owner_main).user
  end

  test "belongs to pantry" do
    # Pantry has its own default_scope keyed off Current.user, so resolving
    # the .pantry association needs Current.session set to a member of it.
    Current.session = sessions(:owner_session)
    assert_equal pantries(:main), pantries_users(:owner_main).pantry
  end

  test "user is required" do
    pu = PantriesUser.new(pantry: pantries(:main), role: :staff)
    assert_not pu.valid?
    assert_includes pu.errors[:user], "must exist"
  end

  test "pantry is required" do
    pu = PantriesUser.new(user: users(:no_pantry_user), role: :staff)
    assert_not pu.valid?
    assert_includes pu.errors[:pantry], "must exist"
  end

  # --- role enum ---

  test "role defaults to staff" do
    pu = PantriesUser.new(user: users(:no_pantry_user), pantry: pantries(:main))
    assert pu.staff?
  end

  test "fixture roles resolve to expected enum values" do
    assert pantries_users(:owner_main).owner?
    assert pantries_users(:admin_main).admin?
    assert pantries_users(:staff_main).staff?
    assert pantries_users(:second_pantry_owner_second).owner?
  end

  test "role can be set via symbol" do
    pu = pantries_users(:staff_main).dup
    pu.role = :admin
    assert pu.admin?
    assert_not pu.staff?
  end

  test "role can be set via string" do
    pu = pantries_users(:staff_main).dup
    pu.role = "owner"
    assert pu.owner?
  end

  test "invalid role raises ArgumentError" do
    assert_raises(ArgumentError) do
      PantriesUser.new(role: :superadmin)
    end
  end

  test "enum defines scopes for each role" do
    assert_includes PantriesUser.staff, pantries_users(:staff_main)
    assert_includes PantriesUser.admin, pantries_users(:admin_main)
    assert_includes PantriesUser.owner, pantries_users(:owner_main)
  end

  test "enum values are ordered staff, admin, owner (0, 1, 2)" do
    assert_equal({ "staff" => 0, "admin" => 1, "owner" => 2 }, PantriesUser.roles)
  end

  # --- uniqueness relies on DB constraint, not a validation ---

  test "there is no ActiveRecord uniqueness validation on the user/pantry combination" do
    validators = PantriesUser.validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
    assert_empty validators
  end

  test "duplicate user/pantry combination raises RecordNotUnique at the DB level" do
    dup = PantriesUser.new(user: users(:owner), pantry: pantries(:main), role: :staff)
    assert dup.valid?, "model-level validation does not catch the duplicate (no uniqueness validator)"
    assert_raises(ActiveRecord::RecordNotUnique) do
      dup.save
    end
  end

  test "same user can belong to different pantries" do
    pu = PantriesUser.create!(user: users(:owner), pantry: pantries(:second), role: :staff)
    assert pu.persisted?
  end

  test "same pantry can have different users" do
    pu = PantriesUser.create!(user: users(:no_pantry_user), pantry: pantries(:main), role: :staff)
    assert pu.persisted?
  end
end
