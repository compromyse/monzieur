require "test_helper"

# Same happy path as PantryLifecycleTest (test/integration/pantry_lifecycle_test.rb),
# but for three pantries that all exist and are actively used at once, with their
# steps interleaved rather than run one after another to completion. Every phase
# below touches all three tenants before moving to the next phase, so if isolation
# ever broke, this would surface it as a wrong count/wrong client/wrong visit rather
# than as a dedicated "refute" assertion -- proving the full lifecycle is correct
# for each tenant specifically because the other two are simultaneously in play,
# not despite them.
class MultiPantryLifecycleTest < ActionDispatch::IntegrationTest
  test "three pantries running the full happy path simultaneously stay fully isolated" do
    tenants = [
      { username: "multi_user_a", pantry_name: "Journey Pantry A", first_name: "Alex",  last_name: "Traveler", household_member: "Sam",   child: "1", adult: "1" },
      { username: "multi_user_b", pantry_name: "Journey Pantry B", first_name: "Blair", last_name: "Nomad",    household_member: "Robin", child: "0", adult: "2" },
      { username: "multi_user_c", pantry_name: "Journey Pantry C", first_name: "Casey", last_name: "Wanderer", household_member: "Drew",  child: "2", adult: "1" },
    ]

    # --- Sign up + create a pantry for each; all three coexist from here on ---
    tenants.each_with_index do |t, i|
      post user_path, params: { username: t[:username], password: "password" }
      assert_response :redirect
      t[:user] = User.unscoped.find_by!(username: t[:username])

      post pantry_index_path, params: { pantry: { name: t[:pantry_name], address: "#{i + 1} #{t[:pantry_name]} Way" } }
      assert_response :redirect
      t[:pantry] = Pantry.unscoped.order(:created_at).last
      assert_equal t[:pantry_name], t[:pantry].name
      assert_equal "owner", PantriesUser.unscoped.find_by!(user: t[:user], pantry: t[:pantry]).role
    end

    # --- Register a client (with a household member) for each, interleaved ---
    tenants.each_with_index do |t, i|
      sign_in_as(t[:user])
      post clients_path(pantry_id: t[:pantry].id), params: {
        client: {
          first_name: t[:first_name],
          last_name: t[:last_name],
          mobile_number: "555555#{i}000",
          address: "#{i + 1} #{t[:pantry_name]} Way",
          infant: "0", toddler: "0", senior: "0",
          child: t[:child], adult: t[:adult],
          household_members_attributes: {
            "0" => { first_name: t[:household_member], last_name: t[:last_name] },
          },
        },
      }
      assert_redirected_to dashboard_index_path(pantry_id: t[:pantry].id)

      Current.pantry = t[:pantry] # reset by the executor after each request above
      t[:client] = Client.unscoped.where(pantry_id: t[:pantry].id).order(:created_at).last
      assert_equal t[:first_name], t[:client].first_name
      assert_equal [t[:household_member]], t[:client].household_members.map(&:first_name)
      assert_equal t[:child].to_i, t[:client].member_counts["child"]
      assert_equal t[:adult].to_i, t[:client].member_counts["adult"]
    end

    # --- Log a visit for each, interleaved ---
    tenants.each do |t|
      sign_in_as(t[:user])
      post visits_path(pantry_id: t[:pantry].id), params: { visit: { client_id: t[:client].id } }
      assert_redirected_to dashboard_index_path(pantry_id: t[:pantry].id)

      Current.pantry = t[:pantry]
      t[:visit] = Visit.unscoped.where(pantry_id: t[:pantry].id).order(:created_at).last
      assert_equal t[:client].id, t[:visit].client_id
      assert_equal t[:user].id, t[:visit].user_id
    end

    # --- Each pantry's own view of itself is correct, with the other two active ---
    tenants.each do |t|
      sign_in_as(t[:user])

      get dashboard_index_path(pantry_id: t[:pantry].id)
      assert_response :success
      assert_equal 1, assigns(:visit_count), "#{t[:pantry_name]} should see exactly its own visit today"

      get visit_history_clients_path(pantry_id: t[:pantry].id, uuid: t[:client].uuid, format: :turbo_stream)
      assert_response :success
      assert_match t[:visit].created_at.strftime("%B"), response.body

      get visits_path(pantry_id: t[:pantry].id)
      assert_response :success
      assert_includes assigns(:visits), t[:visit]

      get daily_signin_visits_path(pantry_id: t[:pantry].id)
      assert_response :success
      assert_equal t[:child].to_i, assigns(:totals)["child"]
      assert_equal t[:adult].to_i, assigns(:totals)["adult"]

      get qr_clients_path(pantry_id: t[:pantry].id, id: t[:client].id)
      assert_response :success

      get intake_form_clients_path(pantry_id: t[:pantry].id, uuid: t[:client].uuid)
      assert_response :success

      get tefap_attestation_clients_path(pantry_id: t[:pantry].id, uuid: t[:client].uuid)
      assert_response :success

      get agreement_clients_path(pantry_id: t[:pantry].id, uuid: t[:client].uuid)
      assert_response :success

      get intake_form_bulk_index_path(pantry_id: t[:pantry].id)
      assert_response :success
      Current.pantry = t[:pantry]
      assert_includes assigns(:clients), t[:client]
    end

    # --- Explicit cross-tenant check: nobody's happy path leaked into anyone else's ---
    tenants.each do |t|
      sign_in_as(t[:user])
      others = tenants - [t]

      get intake_form_bulk_index_path(pantry_id: t[:pantry].id)
      Current.pantry = t[:pantry]
      others.each do |other|
        refute_includes assigns(:clients), other[:client],
          "#{t[:pantry_name]}'s bulk intake must not include #{other[:pantry_name]}'s client"
      end

      get dashboard_index_path(pantry_id: t[:pantry].id)
      assert_equal 1, assigns(:visit_count),
        "#{t[:pantry_name]}'s visit count must not include the other two pantries' visits logged today"
    end
  end
end
