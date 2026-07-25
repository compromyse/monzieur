require "test_helper"

class BulkControllerTest < ActionDispatch::IntegrationTest
  test "intake_form requires authentication" do
    get intake_form_bulk_index_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "intake_form renders successfully for a signed-in pantry member" do
    sign_in_as(users(:owner))

    get intake_form_bulk_index_path(pantry_id: pantries(:main).id)
    assert_response :success
  end

  test "intake_form renders the pdf layout" do
    sign_in_as(users(:owner))

    get intake_form_bulk_index_path(pantry_id: pantries(:main).id)
    assert_response :success
    assert_select "html[data-theme=light]"
  end

  test "intake_form only includes clients for the current pantry" do
    sign_in_as(users(:owner))

    get intake_form_bulk_index_path(pantry_id: pantries(:main).id)
    assert_response :success

    assert_match clients(:jane).name, response.body
    assert_match clients(:john).name, response.body
    refute_match clients(:second_pantry_client).name, response.body
  end

  test "intake_form for a pantry the user doesn't belong to shows no clients" do
    # second_pantry_owner isn't a member of :main, so
    # ApplicationController#set_pantry (Pantry.find_by scoped to the
    # current user's own pantries) leaves Current.pantry nil, and
    # Client.all's default_scope (where(pantry_id: Current.pantry&.id))
    # then returns no clients at all -- not even the requester's own.
    sign_in_as(users(:second_pantry_owner))

    get intake_form_bulk_index_path(pantry_id: pantries(:main).id)
    assert_response :success

    refute_match clients(:jane).name, response.body
    refute_match clients(:john).name, response.body
    refute_match clients(:second_pantry_client).name, response.body
  end
end
