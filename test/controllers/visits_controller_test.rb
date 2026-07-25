require "test_helper"

class VisitsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------

  test "requires authentication for index" do
    get visits_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  # ---------------------------------------------------------------------
  # #create
  # ---------------------------------------------------------------------

  test "create logs a visit for the given client and redirects to the dashboard" do
    sign_in_as(users(:staff))

    assert_difference "Visit.unscoped.count", 1 do
      post visits_path(pantry_id: pantries(:main).id), params: {
        visit: { client_id: clients(:jane).id },
      }
    end

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Visit Logged!", flash[:notice]
  end

  test "create attributes the visit to whoever is logged in, ignoring any smuggled user_id" do
    sign_in_as(users(:staff))

    post visits_path(pantry_id: pantries(:main).id), params: {
      visit: { client_id: clients(:jane).id, user_id: users(:owner).id },
    }

    visit = Visit.unscoped.order(:created_at).last
    assert_equal users(:staff).id, visit.user_id
    refute_equal users(:owner).id, visit.user_id
  end

  test "create assigns the visit to the current pantry" do
    sign_in_as(users(:second_pantry_owner))

    post visits_path(pantry_id: pantries(:second).id), params: {
      visit: { client_id: clients(:second_pantry_client).id },
    }

    visit = Visit.unscoped.order(:created_at).last
    assert_equal pantries(:second).id, visit.pantry_id
  end

  # Real gap: Visit#client is a required belongs_to. A client_id that doesn't
  # resolve under Current.pantry's default_scope (e.g. cross-tenant, or blank)
  # fails validation, so the controller falls through to `render :new` -- but
  # there is no app/views/visits/new template, so this crashes instead of
  # gracefully re-rendering a form.
  test "MULTI-TENANCY: create with a client_id from another pantry fails validation and blows up rendering a nonexistent :new template" do
    sign_in_as(users(:owner)) # :main

    assert_no_difference "Visit.unscoped.count" do
      assert_raises(ActionView::MissingTemplate) do
        post visits_path(pantry_id: pantries(:main).id), params: {
          visit: { client_id: clients(:second_pantry_client).id },
        }
      end
    end
  end

  test "create with a blank client_id fails validation and blows up rendering a nonexistent :new template" do
    sign_in_as(users(:staff))

    assert_no_difference "Visit.unscoped.count" do
      assert_raises(ActionView::MissingTemplate) do
        post visits_path(pantry_id: pantries(:main).id), params: { visit: { client_id: "" } }
      end
    end
  end

  # ---------------------------------------------------------------------
  # #index
  # ---------------------------------------------------------------------

  test "index defaults to today's visits for the current pantry" do
    sign_in_as(users(:staff))

    get visits_path(pantry_id: pantries(:main).id)

    assert_response :success
    assert_includes assigns(:visits), visits(:jane_visit_today)
    refute_includes assigns(:visits), visits(:jane_visit_yesterday)
  end

  test "index respects an explicit ?date= param" do
    sign_in_as(users(:staff))

    get visits_path(pantry_id: pantries(:main).id, date: 1.day.ago.to_date.strftime("%Y-%m-%d"))

    assert_response :success
    assert_includes assigns(:visits), visits(:jane_visit_yesterday)
    refute_includes assigns(:visits), visits(:jane_visit_today)
  end

  test "MULTI-TENANCY: index only shows the current pantry's visits for today" do
    sign_in_as(users(:second_pantry_owner))

    get visits_path(pantry_id: pantries(:second).id)

    assert_response :success
    assert_includes assigns(:visits), visits(:second_pantry_visit_today)
    refute_includes assigns(:visits), visits(:jane_visit_today)
  end

  # ---------------------------------------------------------------------
  # #daily_signin (pdf layout + per-age-bracket totals)
  # ---------------------------------------------------------------------

  test "daily_signin renders successfully" do
    sign_in_as(users(:staff))

    get daily_signin_visits_path(pantry_id: pantries(:main).id)

    assert_response :success
    assert_includes response.content_type, "text/html"
  end

  test "daily_signin totals sum member_counts per age bracket across today's visiting clients" do
    sign_in_as(users(:staff))

    # jane: { infant: 0, toddler: 0, child: 1, adult: 1, senior: 0 } (has a visit today already)
    # give john a visit today too: { infant: 0, toddler: 0, child: 0, adult: 1, senior: 0 }
    Current.pantry = pantries(:main)
    Visit.create!(client: clients(:john), user: users(:staff), created_at: Time.current)

    get daily_signin_visits_path(pantry_id: pantries(:main).id)

    assert_response :success
    totals = assigns(:totals)
    assert_equal 0, totals["infant"]
    assert_equal 0, totals["toddler"]
    assert_equal 1, totals["child"]
    assert_equal 2, totals["adult"]
    assert_equal 0, totals["senior"]
  end

  test "daily_signin totals do not double count a client who visited more than once today" do
    sign_in_as(users(:staff))

    Current.pantry = pantries(:main)
    Visit.create!(client: clients(:jane), user: users(:staff), created_at: Time.current)

    get daily_signin_visits_path(pantry_id: pantries(:main).id)

    assert_response :success
    totals = assigns(:totals)
    # jane alone: child 1, adult 1 -- not doubled despite two visits today
    assert_equal 1, totals["child"]
    assert_equal 1, totals["adult"]
  end

  test "MULTI-TENANCY: daily_signin totals do not include another pantry's clients" do
    sign_in_as(users(:second_pantry_owner))

    get daily_signin_visits_path(pantry_id: pantries(:second).id)

    assert_response :success
    totals = assigns(:totals)
    # second_pantry_client: { infant: 0, toddler: 0, child: 0, adult: 1, senior: 0 }
    assert_equal 1, totals["adult"]
    assert_equal 0, totals["child"], "jane's child count from :main must not leak into :second's totals"
  end
end
