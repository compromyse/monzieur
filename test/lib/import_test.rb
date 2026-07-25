require "test_helper"

# lib/import.rb is a plain Ruby class (not under app/), but
# config/application.rb calls `config.autoload_lib(ignore: %w[assets tasks])`,
# which registers Rails.root.join("lib") with the Zeitwerk `main` autoloader
# (the same one that autoloads everything under app/). That was confirmed
# empirically here with:
#
#   RAILS_ENV=test bin/rails runner 'puts Import.new.class'  #=> Import
#
# So `Import` resolves as a top-level autoloaded constant with no explicit
# `require "import"` needed, exactly like an app/models class would.
class ImportTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------
  # Import#change
  #
  # Traced directly from lib/import.rb: `change(cl)` expects a Hash (or
  # CSV::Row -- anything supporting [], []=, delete) shaped like a "full
  # list" row that has already been tagged with `is_client` and merged with
  # its `dependents` (an array of the same per-row hashes for the other
  # household members under that primary client). It mutates `cl` in place
  # and returns an unsaved Client.
  # ---------------------------------------------------------------------

  def sample_row(overrides = {})
    {
      "id" => 5,
      "Name of Client" => "Jamie Rivera",
      "Total household size" => "3",
      "is_client" => true,
      "infant" => "0",
      "toddler" => "1",
      "child" => "0",
      "adult" => "1",
      "senior" => "0",
      "dependents" => []
    }.merge(overrides)
  end

  def sample_dependent(overrides = {})
    {
      "id" => "6",
      "Name of Client" => "Bailey Rivera",
      "Total household size" => "3",
      "address" => "123 Main St",
      "mobile_number" => "5551234",
      "is_client" => false,
      "infant" => "0",
      "toddler" => "0",
      "child" => "0",
      "adult" => "0",
      "senior" => "0"
    }.merge(overrides)
  end

  test "change splits 'Name of Client' into first_name and last_name" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row)

    assert_equal "Jamie", client.first_name
    assert_equal "Rivera", client.last_name
  end

  test "change joins a multi-word last name back together" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row("Name of Client" => "Mary Anne Smith Jones"))

    assert_equal "Mary", client.first_name
    assert_equal "Anne Smith Jones", client.last_name
  end

  test "change builds member_counts from the age-bracket columns" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row("infant" => "2", "toddler" => "1", "child" => "0", "adult" => "1", "senior" => "3"))

    assert_equal 2, client.member_counts["infant"]
    assert_equal 1, client.member_counts["toddler"]
    assert_equal 0, client.member_counts["child"]
    assert_equal 1, client.member_counts["adult"]
    assert_equal 3, client.member_counts["senior"]
  end

  test "change defaults blank age-bracket values to 0" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row("infant" => "", "toddler" => nil))

    assert_equal 0, client.member_counts["infant"]
    assert_equal 0, client.member_counts["toddler"]
  end

  test "change removes the raw CSV keys from the mutated hash" do
    Current.pantry = pantries(:main)
    row = sample_row
    Import.new.change(row)

    refute row.key?("Name of Client")
    refute row.key?("id")
    refute row.key?("is_client")
    refute row.key?("Total household size")
    refute row.key?("infant")
    refute row.key?("toddler")
    refute row.key?("child")
    refute row.key?("adult")
    refute row.key?("senior")
    refute row.key?("dependents")
  end

  test "change assigns a generated uuid" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row)

    refute_nil client.uuid
    other = Import.new.change(sample_row)
    refute_equal client.uuid, other.uuid
  end

  test "change returns an unsaved Client" do
    Current.pantry = pantries(:main)
    client = Import.new.change(sample_row)

    assert_instance_of Client, client
    refute client.persisted?
  end

  test "change builds a HouseholdMember for each dependent with first/last name split" do
    Current.pantry = pantries(:main)
    row = sample_row("dependents" => [ sample_dependent ])
    client = Import.new.change(row)

    assert_equal 1, client.household_members.size
    member = client.household_members.first
    assert_instance_of HouseholdMember, member
    assert_equal "Bailey", member.first_name
    assert_equal "Rivera", member.last_name
  end

  test "change strips address/id/household-size/mobile/is_client/age columns from dependents" do
    # HouseholdMember has no address/mobile_number/etc columns, so
    # `HouseholdMember.new(d)` would raise ActiveModel::UnknownAttributeError
    # immediately if `change` failed to strip those keys first (confirmed
    # empirically). Not raising, plus a clean name split, demonstrates the
    # stripping happened.
    Current.pantry = pantries(:main)
    row = sample_row("dependents" => [ sample_dependent ])

    client = nil
    assert_nothing_raised do
      client = Import.new.change(row)
    end

    member = client.household_members.first
    assert_equal "Bailey", member.first_name
    assert_equal "Rivera", member.last_name

    # the top-level "dependents" key itself is also removed from the
    # mutated hash once processed
    refute row.key?("dependents")
  end

  test "change supports multiple dependents on one primary client" do
    Current.pantry = pantries(:main)
    row = sample_row("dependents" => [
      sample_dependent("id" => "6", "Name of Client" => "Bailey Rivera"),
      sample_dependent("id" => "7", "Name of Client" => "Casey Rivera")
    ])
    client = Import.new.change(row)

    names = client.household_members.map(&:first_name).sort
    assert_equal [ "Bailey", "Casey" ], names
  end

  # ---------------------------------------------------------------------
  # Import#import_from_csvs
  #
  # Traced directly: reads the "full list" CSV (every row, including
  # primary clients themselves), tags each row is_client: false, then reads
  # the "clients" CSV (just a column of ids) and flips is_client: true for
  # matching rows. Rows are then grouped: each is_client row starts a new
  # "final" entry, and every following non-client row until the next
  # is_client row is nested under it as a dependent (relies on CSV row
  # order -- a client's dependents must immediately follow it in the full
  # list). Finally every group is run through `change` and bulk-inserted
  # with Client.import(final, recursive: true).
  # ---------------------------------------------------------------------

  def write_csv(lines)
    file = Tempfile.new([ "import", ".csv" ])
    file.write(lines.join("\n"))
    file.flush
    file
  end

  setup do
    @full_list_headers = "id,Name of Client,Total household size,infant,toddler,child,adult,senior"
  end

  test "import_from_csvs persists the primary client with correct member_counts" do
    Current.pantry = pantries(:main)

    full = write_csv([
      @full_list_headers,
      "1,Wanda Import,3,0,1,0,1,0"
    ])
    clients_csv = write_csv([ "id", "1" ])

    count = Import.new.import_from_csvs(full.path, clients_csv.path)
    assert_equal 1, count

    client = Client.find_by(first_name: "Wanda", last_name: "Import")
    refute_nil client
    assert_equal pantries(:main).id, client.pantry_id
    assert_equal 1, client.member_counts["toddler"]
    assert_equal 1, client.member_counts["adult"]
    assert_equal 0, client.member_counts["infant"]
  ensure
    full&.close!
    clients_csv&.close!
  end

  test "import_from_csvs nests non-client rows under the preceding client as household_members" do
    Current.pantry = pantries(:main)

    full = write_csv([
      @full_list_headers,
      "1,Wanda Import,3,0,1,0,1,0",
      "2,Wesley Import,3,0,0,0,0,0",
      "3,Vera Import,3,0,0,0,0,0"
    ])
    clients_csv = write_csv([ "id", "1" ])

    count = Import.new.import_from_csvs(full.path, clients_csv.path)
    assert_equal 1, count

    client = Client.find_by(first_name: "Wanda", last_name: "Import")
    members = HouseholdMember.where(client_id: client.id)
    assert_equal 2, members.count
    assert_equal [ "Vera", "Wesley" ], members.map(&:first_name).sort
    members.each { |m| assert_equal pantries(:main).id, m.pantry_id }

    # dependents must never become their own top-level Client
    refute Client.exists?(first_name: "Wesley")
    refute Client.exists?(first_name: "Vera")
  ensure
    full&.close!
    clients_csv&.close!
  end

  test "import_from_csvs handles multiple primary clients each with their own dependents" do
    Current.pantry = pantries(:main)

    full = write_csv([
      @full_list_headers,
      "1,Wanda Import,3,0,1,0,1,0",
      "2,Wesley Import,3,0,0,0,0,0",
      "3,Gary Second,1,0,0,0,1,0",
      "4,Hank Third,2,0,0,0,1,0",
      "5,Ivy Third,2,0,0,1,0,0"
    ])
    clients_csv = write_csv([ "id", "1", "3", "4" ])

    count = Import.new.import_from_csvs(full.path, clients_csv.path)
    assert_equal 3, count

    wanda = Client.find_by(first_name: "Wanda")
    gary = Client.find_by(first_name: "Gary")
    hank = Client.find_by(first_name: "Hank")
    refute_nil wanda
    refute_nil gary
    refute_nil hank

    assert_equal 1, HouseholdMember.where(client_id: wanda.id).count
    assert_equal 0, HouseholdMember.where(client_id: gary.id).count
    assert_equal 1, HouseholdMember.where(client_id: hank.id).count
    assert_equal "Ivy", HouseholdMember.where(client_id: hank.id).first.first_name
  ensure
    full&.close!
    clients_csv&.close!
  end

  test "import_from_csvs defaults blank age-bracket cells to 0" do
    Current.pantry = pantries(:main)

    full = write_csv([
      @full_list_headers,
      "1,Nadia Blank,1,,,,,"
    ])
    clients_csv = write_csv([ "id", "1" ])

    Import.new.import_from_csvs(full.path, clients_csv.path)

    client = Client.find_by(first_name: "Nadia")
    refute_nil client
    %w[infant toddler child adult senior].each do |k|
      assert_equal 0, client.member_counts[k]
    end
  ensure
    full&.close!
    clients_csv&.close!
  end

  test "import_from_csvs returns the number of primary clients, not total rows" do
    Current.pantry = pantries(:main)
    # :main already has the jane/john fixture clients, so compare against a
    # before/after delta rather than an absolute Client.count.
    before_count = Client.count

    full = write_csv([
      @full_list_headers,
      "1,Solo Client,1,0,0,0,1,0",
      "2,Family Head,3,0,0,1,1,0",
      "3,Family Kid,3,0,0,1,0,0"
    ])
    clients_csv = write_csv([ "id", "1", "2" ])

    count = Import.new.import_from_csvs(full.path, clients_csv.path)
    assert_equal 2, count
    assert_equal 2, Client.count - before_count
  ensure
    full&.close!
    clients_csv&.close!
  end

  test "import_from_csvs without Current.pantry set silently fails to persist (real gap)" do
    # Mirrors the ImportsController gap: Client's before_validation
    # assign_pantry reads Current.pantry, and Client.import(recursive: true)
    # validates by default -- so with no Current.pantry, every built Client
    # fails validation and is silently skipped by activerecord-import,
    # while import_from_csvs still returns `final.count` (rows attempted).
    assert_nil Current.pantry

    full = write_csv([
      @full_list_headers,
      "1,No Pantry,1,0,0,0,1,0"
    ])
    clients_csv = write_csv([ "id", "1" ])

    before_count = Client.unscoped.count
    count = Import.new.import_from_csvs(full.path, clients_csv.path)

    assert_equal 1, count, "still reports success even though nothing was persisted"
    assert_equal before_count, Client.unscoped.count
  ensure
    full&.close!
    clients_csv&.close!
  end
end
