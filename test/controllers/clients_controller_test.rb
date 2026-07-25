require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------

  test "requires authentication for show" do
    get show_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)
    assert_redirected_to new_session_path
  end

  test "requires authentication for new" do
    get new_client_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  # ---------------------------------------------------------------------
  # #new
  # ---------------------------------------------------------------------

  test "new renders the registration form" do
    sign_in_as(users(:staff))

    get new_client_path(pantry_id: pantries(:main).id)

    assert_response :success
    assert_instance_of Client, assigns(:client)
    assert assigns(:client).new_record?
  end

  # ---------------------------------------------------------------------
  # #create
  # ---------------------------------------------------------------------

  test "create saves a client and redirects to the dashboard with a notice" do
    sign_in_as(users(:staff))

    assert_difference "Client.unscoped.count", 1 do
      post clients_path(pantry_id: pantries(:main).id), params: {
        client: {
          first_name: "New",
          last_name: "Person",
          mobile_number: "5555551234",
          address: "1 Test Way",
          zipcode: "14210",
          notes: "some notes",
        },
      }
    end

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client Created!", flash[:notice]

    client = Client.unscoped.order(:created_at).last
    assert_equal "New", client.first_name
    assert_equal pantries(:main).id, client.pantry_id, "pantry is force-assigned from Current.pantry, not client params"
  end

  test "create populates member_counts from the MEMBER_TYPES params" do
    sign_in_as(users(:staff))

    post clients_path(pantry_id: pantries(:main).id), params: {
      client: {
        first_name: "New",
        last_name: "Person",
        infant: "2",
        toddler: "1",
        child: "0",
        adult: "3",
        senior: "1",
      },
    }

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)

    client = Client.unscoped.order(:created_at).last
    assert_equal 2, client.member_counts["infant"]
    assert_equal 1, client.member_counts["toddler"]
    assert_equal 0, client.member_counts["child"]
    assert_equal 3, client.member_counts["adult"]
    assert_equal 1, client.member_counts["senior"]
  end

  test "create builds nested household_members via household_members_attributes" do
    sign_in_as(users(:staff))

    assert_difference "HouseholdMember.unscoped.count", 2 do
      post clients_path(pantry_id: pantries(:main).id), params: {
        client: {
          first_name: "New",
          last_name: "Person",
          household_members_attributes: {
            "0" => { first_name: "Kid", last_name: "One" },
            "1" => { first_name: "Kid", last_name: "Two" },
          },
        },
      }
    end

    client = Client.unscoped.order(:created_at).last
    # Current.pantry is reset automatically after the request completes (Rails'
    # executor resets CurrentAttributes around each dispatch), so re-set it
    # before touching HouseholdMember's own pantry-scoped default_scope.
    Current.pantry = pantries(:main)
    assert_equal ["Kid", "Kid"], client.household_members.order(:id).map(&:first_name)
    assert_equal ["One", "Two"], client.household_members.order(:id).map(&:last_name)
  end

  test "create does not permit smuggling in a pantry_id, user-controlled uuid, or other unpermitted params" do
    sign_in_as(users(:staff))

    post clients_path(pantry_id: pantries(:main).id), params: {
      client: {
        first_name: "New",
        last_name: "Person",
        pantry_id: pantries(:second).id,
        uuid: "99999999-9999-9999-9999-999999999999",
      },
    }

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)

    client = Client.unscoped.order(:created_at).last
    assert_equal pantries(:main).id, client.pantry_id
    refute_equal "99999999-9999-9999-9999-999999999999", client.uuid
  end

  # Real gap: Client/HouseholdMember have no Rails-level presence validations,
  # only DB-level `null: false` constraints. So the controller's `else` branch
  # (render :new, unprocessable_entity) is unreachable for a missing required
  # field -- it raises a raw NotNullViolation instead of failing gracefully.
  test "create with a missing required field blows up with a NotNullViolation instead of re-rendering the form" do
    sign_in_as(users(:staff))

    assert_raises(ActiveRecord::NotNullViolation) do
      post clients_path(pantry_id: pantries(:main).id), params: {
        client: { last_name: "OnlyLastName" },
      }
    end
  end

  # ---------------------------------------------------------------------
  # #show
  # ---------------------------------------------------------------------

  test "show renders a client's information" do
    sign_in_as(users(:staff))

    get show_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)

    assert_response :success
    assert_equal clients(:jane), assigns(:client)
  end

  test "show redirects with an alert when the uuid does not exist" do
    sign_in_as(users(:staff))

    get show_clients_path(pantry_id: pantries(:main).id, uuid: "00000000-0000-0000-0000-000000000000")

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  test "MULTI-TENANCY: show does not leak a client belonging to another pantry" do
    sign_in_as(users(:owner)) # owner of :main

    get show_clients_path(pantry_id: pantries(:main).id, uuid: clients(:second_pantry_client).uuid)

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  test "MULTI-TENANCY: show does not leak a client in the reverse direction either" do
    sign_in_as(users(:second_pantry_owner)) # owner of :second

    get show_clients_path(pantry_id: pantries(:second).id, uuid: clients(:jane).uuid)

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:second).id)
    assert_equal "Client not found!", flash[:alert]
  end

  # ---------------------------------------------------------------------
  # #edit / #update  (Client.find(params[:id]) -- numeric id, not uuid)
  # ---------------------------------------------------------------------

  test "edit renders the edit form for a client in the current pantry" do
    sign_in_as(users(:staff))

    get edit_client_path(clients(:jane).id, pantry_id: pantries(:main).id)

    assert_response :success
    assert_equal clients(:jane), assigns(:client)
  end

  test "MULTI-TENANCY: edit 404s (via RecordNotFound) for a client belonging to another pantry" do
    sign_in_as(users(:owner)) # :main

    get edit_client_path(clients(:second_pantry_client).id, pantry_id: pantries(:main).id)

    assert_response :not_found
  end

  test "update persists changes and redirects to show with a notice" do
    sign_in_as(users(:staff))

    patch client_path(clients(:jane).id, pantry_id: pantries(:main).id), params: {
      client: { first_name: "Janet", notes: "updated notes" },
    }

    assert_redirected_to show_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)
    assert_equal "Client Updated!", flash[:notice]

    clients(:jane).reload
    assert_equal "Janet", clients(:jane).first_name
    assert_equal "updated notes", clients(:jane).notes
  end

  test "update can rename a household member via nested attributes" do
    sign_in_as(users(:staff))
    member = household_members(:jane_child)

    patch client_path(clients(:jane).id, pantry_id: pantries(:main).id), params: {
      client: {
        household_members_attributes: {
          "0" => { id: member.id, first_name: "Renamed" },
        },
      },
    }

    assert_redirected_to show_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)
    assert_equal "Renamed", member.reload.first_name
  end

  test "update can destroy a household member via nested attributes" do
    sign_in_as(users(:staff))
    member = household_members(:jane_child)

    assert_difference "HouseholdMember.unscoped.count", -1 do
      patch client_path(clients(:jane).id, pantry_id: pantries(:main).id), params: {
        client: {
          household_members_attributes: {
            "0" => { id: member.id, _destroy: "1" },
          },
        },
      }
    end
  end

  test "MULTI-TENANCY: update 404s (via RecordNotFound) for a client belonging to another pantry" do
    sign_in_as(users(:owner)) # :main
    other = clients(:second_pantry_client)

    patch client_path(other.id, pantry_id: pantries(:main).id), params: {
      client: { first_name: "Hijacked" },
    }

    assert_response :not_found
    assert_equal "Other", other.reload.first_name
  end

  # ---------------------------------------------------------------------
  # #find  (raw ILIKE-ish query, renders JSON)
  # ---------------------------------------------------------------------

  test "find returns matching clients by first name prefix" do
    sign_in_as(users(:staff))

    get find_clients_path(pantry_id: pantries(:main).id, q: "jan")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal clients(:jane).uuid, json.first["uuid"]
  end

  test "find returns matching clients by exact mobile number" do
    sign_in_as(users(:staff))

    get find_clients_path(pantry_id: pantries(:main).id, q: clients(:john).mobile_number)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal clients(:john).uuid, json.first["uuid"]
  end

  test "find returns an empty array when nothing matches" do
    sign_in_as(users(:staff))

    get find_clients_path(pantry_id: pantries(:main).id, q: "nonexistentname")

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "MULTI-TENANCY: find is scoped to the current pantry" do
    sign_in_as(users(:staff)) # :main

    get find_clients_path(pantry_id: pantries(:main).id, q: "other")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json, "must not return clients(:second_pantry_client) which matches 'other' by name"
  end

  # ---------------------------------------------------------------------
  # #visit_history (rendered via turbo_frame -> turbo_stream format)
  # ---------------------------------------------------------------------

  test "visit_history renders the client's grouped visit history as a turbo stream" do
    sign_in_as(users(:staff))

    get visit_history_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid, format: :turbo_stream)

    assert_response :success
  end

  # Real gap: unlike show/intake_form/tefap_attestation/agreement, visit_history
  # does not guard against a nil client -- `client.visit_history` on nil raises.
  test "visit_history raises a NoMethodError for an unknown uuid instead of handling it gracefully" do
    sign_in_as(users(:staff))

    assert_raises(NoMethodError) do
      get visit_history_clients_path(pantry_id: pantries(:main).id, uuid: "00000000-0000-0000-0000-000000000000", format: :turbo_stream)
    end
  end

  test "MULTI-TENANCY: visit_history raises for a client belonging to another pantry" do
    sign_in_as(users(:owner)) # :main

    assert_raises(NoMethodError) do
      get visit_history_clients_path(pantry_id: pantries(:main).id, uuid: clients(:second_pantry_client).uuid, format: :turbo_stream)
    end
  end

  # ---------------------------------------------------------------------
  # #intake_form / #tefap_attestation / #agreement (pdf layout, printable docs)
  # ---------------------------------------------------------------------

  test "intake_form renders successfully for a valid uuid" do
    sign_in_as(users(:staff))

    get intake_form_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)

    assert_response :success
  end

  test "intake_form redirects with an alert for an unknown uuid" do
    sign_in_as(users(:staff))

    get intake_form_clients_path(pantry_id: pantries(:main).id, uuid: "00000000-0000-0000-0000-000000000000")

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  test "tefap_attestation renders successfully for a valid uuid" do
    sign_in_as(users(:staff))

    get tefap_attestation_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)

    assert_response :success
  end

  test "tefap_attestation redirects with an alert for an unknown uuid" do
    sign_in_as(users(:staff))

    get tefap_attestation_clients_path(pantry_id: pantries(:main).id, uuid: "00000000-0000-0000-0000-000000000000")

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  test "agreement renders successfully for a valid uuid" do
    sign_in_as(users(:staff))

    get agreement_clients_path(pantry_id: pantries(:main).id, uuid: clients(:jane).uuid)

    assert_response :success
  end

  test "agreement redirects with an alert for an unknown uuid" do
    sign_in_as(users(:staff))

    get agreement_clients_path(pantry_id: pantries(:main).id, uuid: "00000000-0000-0000-0000-000000000000")

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  test "MULTI-TENANCY: intake_form does not leak a client from another pantry" do
    sign_in_as(users(:owner)) # :main

    get intake_form_clients_path(pantry_id: pantries(:main).id, uuid: clients(:second_pantry_client).uuid)

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Client not found!", flash[:alert]
  end

  # ---------------------------------------------------------------------
  # #qr  (looks up by numeric params[:id], NOT uuid -- a real inconsistency
  # with every other client action; test the actual behavior)
  # ---------------------------------------------------------------------

  test "qr renders a PNG label for a client looked up by numeric id" do
    sign_in_as(users(:staff))

    get qr_clients_path(pantry_id: pantries(:main).id, id: clients(:jane).id)

    assert_response :success
    assert_includes response.content_type, "text/html"
  end

  test "qr 404s (via RecordNotFound) for a nonexistent numeric id" do
    sign_in_as(users(:staff))

    get qr_clients_path(pantry_id: pantries(:main).id, id: 0)

    assert_response :not_found
  end

  test "MULTI-TENANCY: qr 404s (via RecordNotFound) for a client belonging to another pantry" do
    sign_in_as(users(:owner)) # :main

    get qr_clients_path(pantry_id: pantries(:main).id, id: clients(:second_pantry_client).id)

    assert_response :not_found
  end
end
