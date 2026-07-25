require "test_helper"

class HouseholdMemberTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------
  # MEMBER_TYPES
  # ---------------------------------------------------------------------

  test "MEMBER_TYPES has the expected keys and human-readable labels" do
    expected = {
      infant: "Infant (< 2)",
      toddler: "Toddler (2-5)",
      child: "Child (6-17)",
      adult: "Adult (18-59)",
      senior: "Senior (60+)"
    }

    assert_equal expected, HouseholdMember::MEMBER_TYPES
  end

  # ---------------------------------------------------------------------
  # belongs_to :client
  # ---------------------------------------------------------------------

  test "belongs_to :client is required" do
    Current.pantry = pantries(:main)

    member = HouseholdMember.new(first_name: "No", last_name: "Client")
    refute member.valid?
    assert_includes member.errors[:client], "must exist"
  end

  test "belongs_to :client resolves the associated client" do
    Current.pantry = pantries(:main)

    member = household_members(:jane_child)
    assert_equal clients(:jane), member.client
  end

  # ---------------------------------------------------------------------
  # Multi-tenancy: default_scope { where(pantry_id: Current.pantry&.id) }
  # ---------------------------------------------------------------------

  test "fixture accessor works regardless of Current.pantry" do
    assert_nil Current.pantry
    assert_equal "Jimmy", household_members(:jane_child).first_name
  end

  test "HouseholdMember.all only returns members for the current pantry" do
    Current.pantry = pantries(:main)

    ids = HouseholdMember.all.map(&:id)
    assert_includes ids, household_members(:jane_child).id
  end

  test "HouseholdMember.all excludes members from another pantry" do
    Current.pantry = pantries(:second)
    other_member = HouseholdMember.create!(
      client: clients(:second_pantry_client),
      first_name: "Other",
      last_name: "Kid"
    )

    Current.pantry = pantries(:main)
    ids = HouseholdMember.all.map(&:id)
    refute_includes ids, other_member.id
    assert_includes ids, household_members(:jane_child).id

    Current.pantry = pantries(:second)
    ids = HouseholdMember.all.map(&:id)
    assert_includes ids, other_member.id
    refute_includes ids, household_members(:jane_child).id
  end

  test "HouseholdMember.all is empty when Current.pantry is nil" do
    assert_nil Current.pantry
    assert_equal [], HouseholdMember.all.to_a
  end

  test "HouseholdMember.find raises for a member outside the current pantry" do
    Current.pantry = pantries(:second)

    assert_raises(ActiveRecord::RecordNotFound) do
      HouseholdMember.find(household_members(:jane_child).id)
    end
  end

  # ---------------------------------------------------------------------
  # assign_pantry: self.pantry ||= Current.pantry (guarded, unlike Client/Visit)
  # ---------------------------------------------------------------------

  test "assign_pantry falls back to Current.pantry when pantry is not set" do
    Current.pantry = pantries(:main)

    member = HouseholdMember.create!(
      client: clients(:jane),
      first_name: "New",
      last_name: "Kid"
    )

    assert_equal pantries(:main).id, member.pantry_id
  end

  test "assign_pantry respects an explicitly assigned pantry instead of overwriting it" do
    Current.pantry = pantries(:main)

    member = HouseholdMember.create!(
      client: clients(:jane),
      pantry: pantries(:second),
      first_name: "New",
      last_name: "Kid"
    )

    # Unlike Client/Visit, HouseholdMember uses ||= so an explicit pantry wins.
    assert_equal pantries(:second).id, member.pantry_id
    refute_equal pantries(:main).id, member.pantry_id
  end

  test "creating a household_member without Current.pantry or an explicit pantry is invalid" do
    assert_nil Current.pantry

    member = HouseholdMember.new(client: clients(:jane), first_name: "New", last_name: "Kid")
    refute member.valid?
    assert_raises(ActiveRecord::RecordInvalid) { member.save! }
  end

  # ---------------------------------------------------------------------
  # first_name / last_name: DB NOT NULL, no app-level presence validation
  # ---------------------------------------------------------------------

  test "first_name has no app-level presence validation but is required at the DB level" do
    Current.pantry = pantries(:main)

    member = HouseholdMember.new(client: clients(:jane), first_name: nil, last_name: "Kid")
    assert member.valid?, "expected no app-level validation error for a nil first_name"

    assert_raises(ActiveRecord::NotNullViolation) do
      member.save
    end
  end

  test "last_name has no app-level presence validation but is required at the DB level" do
    Current.pantry = pantries(:main)

    member = HouseholdMember.new(client: clients(:jane), first_name: "Kid", last_name: nil)
    assert member.valid?, "expected no app-level validation error for a nil last_name"

    assert_raises(ActiveRecord::NotNullViolation) do
      member.save
    end
  end
end
