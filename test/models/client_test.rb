require "test_helper"

class ClientTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------
  # Multi-tenancy: default_scope { where(pantry_id: Current.pantry&.id) }
  # ---------------------------------------------------------------------

  test "fixture accessors work regardless of Current.pantry" do
    # Rails wraps fixture accessors in .unscoped, so these always resolve
    # even though Current.pantry is nil (the default outside a request).
    assert_nil Current.pantry
    assert_equal "Jane", clients(:jane).first_name
    assert_equal "Other", clients(:second_pantry_client).first_name
  end

  test "Client.all only returns clients for the current pantry" do
    Current.pantry = pantries(:main)

    ids = Client.all.map(&:id)
    assert_includes ids, clients(:jane).id
    assert_includes ids, clients(:john).id
    refute_includes ids, clients(:second_pantry_client).id
  end

  test "Client.all flips over when Current.pantry changes" do
    Current.pantry = pantries(:second)

    ids = Client.all.map(&:id)
    assert_includes ids, clients(:second_pantry_client).id
    refute_includes ids, clients(:jane).id
    refute_includes ids, clients(:john).id
  end

  test "Client.all is empty when Current.pantry is nil" do
    assert_nil Current.pantry
    assert_equal [], Client.all.to_a
  end

  test "Client.find raises for a client outside the current pantry" do
    Current.pantry = pantries(:second)

    assert_raises(ActiveRecord::RecordNotFound) do
      Client.find(clients(:jane).id)
    end
  end

  test "Client.find raises for any client when Current.pantry is nil" do
    assert_nil Current.pantry

    assert_raises(ActiveRecord::RecordNotFound) do
      Client.find(clients(:jane).id)
    end
  end

  test "Client.where is scoped by Current.pantry" do
    Current.pantry = pantries(:main)

    assert_equal 0, Client.where(id: clients(:second_pantry_client).id).count
    assert_equal 1, Client.where(id: clients(:jane).id).count
  end

  # ---------------------------------------------------------------------
  # assign_pantry: before_validation on create, unconditionally overwrites
  # ---------------------------------------------------------------------

  test "assign_pantry sets pantry from Current.pantry on create" do
    Current.pantry = pantries(:main)

    client = Client.create!(first_name: "New", last_name: "Person")
    assert_equal pantries(:main).id, client.pantry_id
  end

  test "assign_pantry overwrites an explicitly assigned pantry on create" do
    Current.pantry = pantries(:main)

    client = Client.create!(first_name: "New", last_name: "Person", pantry: pantries(:second))
    assert_equal pantries(:main).id, client.pantry_id
    refute_equal pantries(:second).id, client.pantry_id
  end

  test "creating a client without Current.pantry set is invalid" do
    assert_nil Current.pantry

    client = Client.new(first_name: "New", last_name: "Person")
    refute client.valid?
    assert_raises(ActiveRecord::RecordInvalid) { client.save! }
  end

  # ---------------------------------------------------------------------
  # member_counts typed_store
  # ---------------------------------------------------------------------

  test "member_counts defaults every MEMBER_TYPES key to 0" do
    Current.pantry = pantries(:main)

    client = Client.create!(first_name: "New", last_name: "Person")
    HouseholdMember::MEMBER_TYPES.keys.each do |key|
      assert_equal 0, client.member_counts[key.to_s]
    end
  end

  test "member_counts fields are readable/writable as typed attributes" do
    Current.pantry = pantries(:main)
    client = clients(:jane)

    client.infant = 2
    client.save!

    reloaded_client = Client.find(clients(:jane).id)
    assert_equal 2, reloaded_client.infant
    assert_equal 2, reloaded_client.member_counts["infant"]
  end

  test "member_counts persists across reload for every member type" do
    Current.pantry = pantries(:main)
    client = clients(:jane)

    client.toddler = 3
    client.senior = 1
    client.save!
    client.reload

    assert_equal 3, client.member_counts["toddler"]
    assert_equal 1, client.member_counts["senior"]
  end

  # ---------------------------------------------------------------------
  # accepts_nested_attributes_for :household_members
  # ---------------------------------------------------------------------

  test "creating a client with nested household_members_attributes creates members" do
    Current.pantry = pantries(:main)

    client = Client.create!(
      first_name: "New",
      last_name: "Person",
      household_members_attributes: [
        { first_name: "Kid", last_name: "One" },
        { first_name: "Kid", last_name: "Two" }
      ]
    )

    assert_equal 2, client.household_members.count
    assert_equal ["Kid", "Kid"], client.household_members.map(&:first_name).sort
  end

  test "nested household_members_attributes rows that are all blank are rejected" do
    Current.pantry = pantries(:main)

    client = Client.create!(
      first_name: "New",
      last_name: "Person",
      household_members_attributes: [
        { first_name: "", last_name: "" }
      ]
    )

    assert_equal 0, client.household_members.count
  end

  test "updating a client can update an existing household_member via nested attributes" do
    Current.pantry = pantries(:main)
    client = clients(:jane)
    member = household_members(:jane_child)

    client.update!(
      household_members_attributes: [
        { id: member.id, first_name: "Renamed" }
      ]
    )

    assert_equal "Renamed", member.reload.first_name
  end

  test "updating a client can destroy a household_member via nested attributes with allow_destroy" do
    Current.pantry = pantries(:main)
    client = clients(:jane)
    member = household_members(:jane_child)

    client.update!(
      household_members_attributes: [
        { id: member.id, _destroy: "1" }
      ]
    )

    assert_raises(ActiveRecord::RecordNotFound) { HouseholdMember.find(member.id) }
  end

  # ---------------------------------------------------------------------
  # name
  # ---------------------------------------------------------------------

  test "name joins first and last name" do
    assert_equal "Jane Doe", clients(:jane).name
    assert_equal "John Smith", clients(:john).name
  end

  # ---------------------------------------------------------------------
  # last_visit
  # ---------------------------------------------------------------------

  test "last_visit returns '-' when the client has no visits" do
    Current.pantry = pantries(:main)
    client = clients(:john) # no visits fixture for john

    assert_equal "-", client.last_visit
  end

  test "last_visit returns the formatted date of the most recent visit" do
    Current.pantry = pantries(:main)
    client = clients(:jane)

    expected = visits(:jane_visit_today).created_at.to_date.to_fs(:long)
    assert_equal expected, client.last_visit
  end

  # ---------------------------------------------------------------------
  # visit_history
  # ---------------------------------------------------------------------

  test "visit_history groups visits by year and then by month name" do
    Current.pantry = pantries(:main)
    client = clients(:john)

    # Use Time.zone.local (not Time.utc) — the app runs in Eastern time
    # (config.time_zone), and a UTC midnight timestamp near a year boundary
    # shifts to the previous day (and year) once converted for display.
    Visit.create!(client: client, user: users(:staff), created_at: Time.zone.local(2023, 1, 15))
    Visit.create!(client: client, user: users(:staff), created_at: Time.zone.local(2023, 1, 20))
    Visit.create!(client: client, user: users(:staff), created_at: Time.zone.local(2023, 6, 1))
    Visit.create!(client: client, user: users(:staff), created_at: Time.zone.local(2024, 1, 1))

    history = client.visit_history

    assert_equal [2024, 2023].sort.reverse, history.keys.sort.reverse
    assert_includes history[2023].keys, "January"
    assert_includes history[2023].keys, "June"
    assert_equal 2, history[2023]["January"].size
    assert_equal 1, history[2023]["June"].size
    assert_includes history[2024].keys, "January"
    assert_equal 1, history[2024]["January"].size
  end

  test "visit_history is empty for a client with no visits" do
    Current.pantry = pantries(:main)
    client = clients(:john)

    assert_equal({}, client.visit_history)
  end

  # ---------------------------------------------------------------------
  # uuid uniqueness
  # ---------------------------------------------------------------------

  test "uuid is auto-generated and unique per client" do
    Current.pantry = pantries(:main)

    client = Client.create!(first_name: "New", last_name: "Person")
    refute_nil client.uuid
    refute_equal clients(:jane).uuid, client.uuid
  end

  test "duplicate uuid values are rejected at the database level" do
    Current.pantry = pantries(:main)

    duplicate = Client.new(
      first_name: "Dup",
      last_name: "Client",
      uuid: clients(:jane).uuid
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!
    end
  end
end
