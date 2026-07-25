require "test_helper"

# End-to-end happy-path coverage: unlike the per-controller tests (which each
# work against pre-seeded fixtures in isolation), this walks one continuous
# journey through freshly-created records, the way a real user actually
# would: sign up -> create a pantry -> register a client -> log a visit ->
# check it shows up everywhere it should (dashboard, visit history, visit
# index, daily sign-in totals) -> generate every printable document for that
# client -> bulk-print blank intake forms for the whole pantry.
class PantryLifecycleTest < ActionDispatch::IntegrationTest
  test "new pantry -> new client -> log visit -> visit history -> all documents" do
    # --- Sign up ---
    post user_path, params: { username: "journey_user", password: "password" }
    assert_response :redirect
    user = User.unscoped.find_by!(username: "journey_user")

    # --- Create a pantry (auto-assigns the creator as owner) ---
    post pantry_index_path, params: { pantry: { name: "Journey Pantry", address: "1 Journey Way" } }
    assert_response :redirect
    pantry = Pantry.unscoped.order(:created_at).last
    assert_equal "Journey Pantry", pantry.name
    assert_equal "owner", PantriesUser.unscoped.find_by!(user: user, pantry: pantry).role

    # --- Register a client with household members ---
    post clients_path(pantry_id: pantry.id), params: {
      client: {
        first_name: "Alex",
        last_name: "Traveler",
        mobile_number: "5555559999",
        address: "2 Journey Way",
        zipcode: "14210",
        infant: "0",
        toddler: "0",
        child: "1",
        adult: "1",
        senior: "0",
        household_members_attributes: {
          "0" => { first_name: "Sam", last_name: "Traveler" },
        },
      },
    }
    assert_redirected_to dashboard_index_path(pantry_id: pantry.id)
    client = Client.unscoped.order(:created_at).last
    assert_equal "Alex", client.first_name
    assert_equal pantry.id, client.pantry_id

    Current.pantry = pantry # reset by the executor after each request above
    assert_equal ["Sam"], client.household_members.map(&:first_name)
    assert_equal 1, client.member_counts["child"]

    # --- Log a visit ---
    post visits_path(pantry_id: pantry.id), params: { visit: { client_id: client.id } }
    assert_redirected_to dashboard_index_path(pantry_id: pantry.id)
    Current.pantry = pantry
    visit = Visit.unscoped.order(:created_at).last
    assert_equal client.id, visit.client_id
    assert_equal user.id, visit.user_id

    # --- Dashboard shows today's visit count ---
    get dashboard_index_path(pantry_id: pantry.id)
    assert_response :success
    assert_equal 1, assigns(:visit_count)

    # --- Visit history (turbo stream) reflects the logged visit ---
    get visit_history_clients_path(pantry_id: pantry.id, uuid: client.uuid, format: :turbo_stream)
    assert_response :success
    assert_match visit.created_at.strftime("%B"), response.body

    # --- Visit index lists it for today ---
    get visits_path(pantry_id: pantry.id)
    assert_response :success
    assert_includes assigns(:visits), visit

    # --- Daily sign-in totals include this client's household ---
    get daily_signin_visits_path(pantry_id: pantry.id)
    assert_response :success
    assert_equal 1, assigns(:totals)["child"]
    assert_equal 1, assigns(:totals)["adult"]

    # --- Every printable document for this client renders ---
    get qr_clients_path(pantry_id: pantry.id, id: client.id)
    assert_response :success

    get intake_form_clients_path(pantry_id: pantry.id, uuid: client.uuid)
    assert_response :success

    get tefap_attestation_clients_path(pantry_id: pantry.id, uuid: client.uuid)
    assert_response :success

    get agreement_clients_path(pantry_id: pantry.id, uuid: client.uuid)
    assert_response :success

    # --- Bulk blank intake forms for the whole pantry include this client ---
    get intake_form_bulk_index_path(pantry_id: pantry.id)
    assert_response :success
    Current.pantry = pantry
    assert_includes assigns(:clients), client
  end
end
