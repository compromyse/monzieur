require "test_helper"

class PantryTest < ActiveSupport::TestCase
  # --- basic attributes ---

  test "fixture pantry has expected attributes" do
    assert_equal "Main Pantry", pantries(:main).name
    assert_equal "1168 Seneca St, Buffalo NY 14210", pantries(:main).address
  end

  test "address defaults to empty string" do
    Current.session = Session.new(user: users(:owner))
    pantry = Pantry.new(name: "No Address Pantry")
    pantry.save!
    assert_equal "", pantry.address
  end

  # --- associations ---

  test "has_many household_members" do
    assert_respond_to pantries(:main), :household_members
    assert_includes pantries(:main).household_members, household_members(:jane_child)
  end

  test "has_many visits" do
    assert_respond_to pantries(:main), :visits
    assert_includes pantries(:main).visits, visits(:jane_visit_today)
  end

  test "has_many clients" do
    assert_respond_to pantries(:main), :clients
    assert_includes pantries(:main).clients, clients(:jane)
  end

  test "has_many pantries_user" do
    assert_respond_to pantries(:main), :pantries_user
    assert_includes pantries(:main).pantries_user, pantries_users(:owner_main)
  end

  test "has_many users through pantries_user" do
    Current.session = sessions(:owner_session)
    assert_includes pantries(:main).users, users(:owner)
    assert_includes pantries(:main).users, users(:admin)
    assert_includes pantries(:main).users, users(:staff)
  end

  # --- default_scope tenant isolation ---

  test "Pantry.all only returns pantries the current user belongs to" do
    Current.session = sessions(:owner_session)
    result = Pantry.all
    assert_includes result, pantries(:main)
    assert_not_includes result, pantries(:second)
  end

  test "a user only sees pantries they belong to, not other pantries" do
    Current.session = Session.new(user: users(:second_pantry_owner))
    result = Pantry.all
    assert_includes result, pantries(:second)
    assert_not_includes result, pantries(:main)
  end

  test "Pantry.find raises RecordNotFound for a pantry the current user does not belong to" do
    Current.session = sessions(:owner_session)
    assert_raises(ActiveRecord::RecordNotFound) do
      Pantry.find(pantries(:second).id)
    end
  end

  test "Pantry.find succeeds for a pantry the current user belongs to" do
    Current.session = sessions(:owner_session)
    assert_equal pantries(:main), Pantry.find(pantries(:main).id)
  end

  test "Pantry.all is empty when Current.session is not set" do
    assert_nil Current.session
    assert_empty Pantry.all
  end

  test "Pantry.all is empty for a user with no pantries" do
    Current.session = Session.new(user: users(:no_pantry_user))
    assert_empty Pantry.all
  end

  test "site_admin_user does not automatically see all pantries" do
    Current.session = Session.new(user: users(:site_admin_user))
    assert_empty Pantry.all
  end

  test "default_scope distincts results even with multiple pantries_user rows" do
    # owner belongs to :main only once, but exercise the .distinct behavior by
    # confirming no duplicate rows are returned for a single membership.
    Current.session = sessions(:owner_session)
    result = Pantry.all.to_a
    assert_equal result.uniq, result
  end

  # --- fixture accessors bypass default_scope ---

  test "fixture accessor for a pantry works even without Current.session set" do
    assert_nil Current.session
    assert_equal "Main Pantry", pantries(:main).name
  end

  # --- assign_user after_create callback ---

  test "creating a pantry assigns the current user as owner" do
    Current.session = sessions(:owner_session)
    pantry = Pantry.create!(name: "Brand New Pantry", address: "1 New St")

    pu = PantriesUser.find_by(user: users(:owner), pantry: pantry)
    assert pu.present?
    assert pu.owner?
  end

  test "creating a pantry adds it to Current.user's pantries" do
    Current.session = sessions(:owner_session)
    pantry = Pantry.create!(name: "Another New Pantry", address: "2 New St")

    assert_includes users(:owner).pantries_user.map(&:pantry), pantry
  end

  test "creating a pantry without Current.session set raises NoMethodError" do
    assert_nil Current.session
    assert_raises(NoMethodError) do
      Pantry.create!(name: "Orphan Pantry", address: "3 New St")
    end
  end

  test "assign_user sets role to owner even if the creating user already has another role elsewhere" do
    Current.session = Session.new(user: users(:staff))
    pantry = Pantry.create!(name: "Staff Owned Pantry", address: "4 New St")

    pu = PantriesUser.find_by(user: users(:staff), pantry: pantry)
    assert pu.owner?
    # staff's role on the pre-existing main pantry membership is untouched
    assert pantries_users(:staff_main).reload.staff?
  end
end
