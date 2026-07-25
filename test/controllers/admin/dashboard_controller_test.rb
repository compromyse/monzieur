require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  # Admin::BaseController includes the Authentication concern directly
  # (it isn't an ApplicationController subclass), so require_authentication
  # still applies even though there's no pantry_id in the /admin/* routes.

  test "unauthenticated visitors are redirected to the login page" do
    get admin_index_path
    assert_redirected_to new_session_path
  end

  test "an authenticated non-site-admin is redirected to root" do
    sign_in_as(users(:owner))

    get admin_index_path
    assert_redirected_to root_url
  end

  test "an authenticated pantry admin-role (but not site_admin) user is redirected to root" do
    # 'admin' here is a pantries_user role of :admin, not User#site_admin -
    # authorize_admin! only looks at Current.user.site_admin?, so this
    # pantry-level admin is still turned away.
    sign_in_as(users(:admin))

    get admin_index_path
    assert_redirected_to root_url
  end

  test "the site_admin_user can access the dashboard" do
    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success
  end

  # ---------------------------------------------------------------------
  # KNOWN GAP: Admin::DashboardController#index sets
  #   @pantries = Pantry.all.count
  # but Pantry has its own default_scope:
  #   joins(:pantries_user).where(pantries_user: { user_id: Current.user&.id })
  # so "Pantry.all" here is silently scoped to the *currently signed-in
  # site_admin's own* pantry memberships, not a true cross-tenant total.
  # It is NOT .unscoped like @household_members is. The fixture
  # site_admin_user has no pantries_users row at all, so @pantries reads 0
  # even though multiple pantries exist in the database.
  # ---------------------------------------------------------------------

  test "@pantries reflects the site_admin's own pantry memberships, not the true total (real bug)" do
    assert_equal 2, Pantry.unscoped.count, "sanity check: there really are 2 pantries in the fixtures"

    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    rows = doc.css("div.flex.items-center.justify-between")
    pantries_value = rows[0].css("span")[1].text.strip

    # site_admin_user has zero pantries_users rows, so the scoped count is 0,
    # not the true total of 2.
    assert_equal "0", pantries_value
  end

  test "@pantries changes based on which pantries the signed-in site_admin belongs to" do
    PantriesUser.create!(user: users(:site_admin_user), pantry: pantries(:main), role: :staff)

    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    rows = doc.css("div.flex.items-center.justify-between")
    pantries_value = rows[0].css("span")[1].text.strip

    # Now the site_admin belongs to exactly 1 of the 2 real pantries, and
    # @pantries follows that membership count rather than the true total.
    assert_equal "1", pantries_value
    assert_equal 2, Pantry.unscoped.count
  end

  test "@household_members correctly reflects the true cross-tenant total via .unscoped" do
    assert_equal 1, HouseholdMember.unscoped.count, "sanity check: only the jane_child fixture exists"

    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    rows = doc.css("div.flex.items-center.justify-between")
    household_members_value = rows[1].css("span")[1].text.strip

    assert_equal "1", household_members_value
  end

  test "@household_members total grows as household members are added across pantries" do
    Current.pantry = pantries(:second)
    HouseholdMember.create!(client: clients(:second_pantry_client), first_name: "Extra", last_name: "Member")
    Current.pantry = nil

    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    rows = doc.css("div.flex.items-center.justify-between")
    household_members_value = rows[1].css("span")[1].text.strip

    assert_equal "2", household_members_value
  end

  test "renders with the admin layout" do
    sign_in_as(users(:site_admin_user))

    get admin_index_path
    assert_response :success
    assert_select "nav a", text: "Pantrie Admin"
  end
end
