require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------

  test "redirects to login when not authenticated" do
    get dashboard_index_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  # ---------------------------------------------------------------------
  # @visit_count = Visit.where(created_at: Time.current.all_day).count
  # ---------------------------------------------------------------------

  test "counts today's visits and excludes visits from other days" do
    sign_in_as(users(:staff))

    get dashboard_index_path(pantry_id: pantries(:main).id)

    assert_response :success
    # main has jane_visit_today (included) and jane_visit_yesterday (excluded)
    assert_equal 1, assigns(:visit_count)
  end

  test "visit count only reflects the current pantry's visits (via Visit's default_scope)" do
    sign_in_as(users(:second_pantry_owner))

    get dashboard_index_path(pantry_id: pantries(:second).id)

    assert_response :success
    # second only has second_pantry_visit_today; main's jane_visit_today must not leak in,
    # even though the controller's query itself isn't explicitly scoped by pantry_id.
    assert_equal 1, assigns(:visit_count)
  end

  test "visit count is 0 when the pantry has no visits today" do
    sign_in_as(users(:staff))
    Current.pantry = pantries(:main)
    Visit.where(client: clients(:jane)).destroy_all
    Current.reset

    get dashboard_index_path(pantry_id: pantries(:main).id)

    assert_response :success
    assert_equal 0, assigns(:visit_count)
  end

  test "renders successfully for an admin (owner) user" do
    sign_in_as(users(:owner))

    get dashboard_index_path(pantry_id: pantries(:main).id)

    assert_response :success
  end

  test "renders successfully for a non-admin (staff) user" do
    sign_in_as(users(:staff))

    get dashboard_index_path(pantry_id: pantries(:main).id)

    assert_response :success
  end

  # ---------------------------------------------------------------------
  # Real gap: a user with no pantries_user row for the requested pantry_id
  # is a non-member, so Pantry.find_by(id: ...) (scoped by Current.user via
  # Pantry's own default_scope) silently resolves to nil -> Current.pantry
  # stays nil. The view's first pantry-scoped path helper (new_client_path,
  # relying on default_url_options' pantry_id: Current.pantry&.id) then
  # fails to generate a route, crashing the page instead of denying access
  # gracefully.
  # ---------------------------------------------------------------------

  test "a user with no pantry membership crashes the dashboard instead of being denied gracefully" do
    sign_in_as(users(:no_pantry_user))

    assert_raises(ActionView::Template::Error) do
      get dashboard_index_path(pantry_id: pantries(:main).id)
    end
  end
end
