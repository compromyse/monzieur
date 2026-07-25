require "test_helper"

class VisitTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------

  test "belongs_to :client is required" do
    Current.pantry = pantries(:main)

    visit = Visit.new(user: users(:staff))
    refute visit.valid?
    assert_includes visit.errors[:client], "must exist"
  end

  test "belongs_to :user is required" do
    Current.pantry = pantries(:main)

    visit = Visit.new(client: clients(:jane))
    refute visit.valid?
    assert_includes visit.errors[:user], "must exist"
  end

  test "belongs_to :pantry is required" do
    assert_nil Current.pantry

    visit = Visit.new(client: clients(:jane), user: users(:staff))
    refute visit.valid?
    assert_includes visit.errors[:pantry], "must exist"
  end

  test "visit resolves its client, user, and pantry associations" do
    Current.pantry = pantries(:main)
    # Pantry itself has a default_scope keyed off Current.user (not Current.pantry),
    # so resolving visit.pantry needs Current.session set too.
    Current.session = sessions(:owner_session)
    visit = visits(:jane_visit_today)

    assert_equal clients(:jane), visit.client
    assert_equal users(:staff), visit.user
    assert_equal pantries(:main), visit.pantry
  end

  # ---------------------------------------------------------------------
  # Multi-tenancy: default_scope { where(pantry_id: Current.pantry&.id) }
  # ---------------------------------------------------------------------

  test "fixture accessors work regardless of Current.pantry" do
    # The fixture accessors themselves (visits(:x)) bypass default_scope
    # entirely (Rails wraps fixture lookups in .unscoped), regardless of
    # Current.pantry. Calling .client on the resolved record is a separate,
    # scoped operation, so Current.pantry has to match for it to resolve.
    assert_nil Current.pantry
    assert_instance_of Visit, visits(:jane_visit_today)
    assert_instance_of Visit, visits(:second_pantry_visit_today)

    Current.pantry = pantries(:main)
    assert_equal clients(:jane), visits(:jane_visit_today).client

    Current.pantry = pantries(:second)
    assert_equal clients(:second_pantry_client), visits(:second_pantry_visit_today).client
  end

  test "Visit.all only returns visits for the current pantry" do
    Current.pantry = pantries(:main)

    ids = Visit.all.map(&:id)
    assert_includes ids, visits(:jane_visit_today).id
    assert_includes ids, visits(:jane_visit_yesterday).id
    refute_includes ids, visits(:second_pantry_visit_today).id
  end

  test "Visit.all flips over when Current.pantry changes" do
    Current.pantry = pantries(:second)

    ids = Visit.all.map(&:id)
    assert_includes ids, visits(:second_pantry_visit_today).id
    refute_includes ids, visits(:jane_visit_today).id
    refute_includes ids, visits(:jane_visit_yesterday).id
  end

  test "Visit.all is empty when Current.pantry is nil" do
    assert_nil Current.pantry
    assert_equal [], Visit.all.to_a
  end

  test "Visit.find raises for a visit outside the current pantry" do
    Current.pantry = pantries(:second)

    assert_raises(ActiveRecord::RecordNotFound) do
      Visit.find(visits(:jane_visit_today).id)
    end
  end

  test "Visit.find raises for any visit when Current.pantry is nil" do
    assert_nil Current.pantry

    assert_raises(ActiveRecord::RecordNotFound) do
      Visit.find(visits(:jane_visit_today).id)
    end
  end

  test "association loads through client.visits are scoped by Current.pantry" do
    Current.pantry = pantries(:main)
    assert_equal 2, clients(:jane).visits.count

    Current.pantry = pantries(:second)
    assert_equal 0, clients(:jane).visits.count
  end

  # ---------------------------------------------------------------------
  # assign_pantry: before_validation on create, unconditionally overwrites
  # ---------------------------------------------------------------------

  test "assign_pantry sets pantry from Current.pantry on create" do
    Current.pantry = pantries(:main)

    visit = Visit.create!(client: clients(:jane), user: users(:staff))
    assert_equal pantries(:main).id, visit.pantry_id
  end

  test "assign_pantry overwrites an explicitly assigned pantry on create" do
    Current.pantry = pantries(:main)

    visit = Visit.create!(client: clients(:jane), user: users(:staff), pantry: pantries(:second))
    assert_equal pantries(:main).id, visit.pantry_id
    refute_equal pantries(:second).id, visit.pantry_id
  end

  test "creating a visit without Current.pantry set is invalid" do
    assert_nil Current.pantry

    visit = Visit.new(client: clients(:jane), user: users(:staff))
    refute visit.valid?
    assert_raises(ActiveRecord::RecordInvalid) { visit.save! }
  end
end
