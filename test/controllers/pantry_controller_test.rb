require "test_helper"

class PantryControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------
  # index (root path)
  # ---------------------------------------------------------------------

  test "index requires authentication" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "index only lists pantries the current user belongs to" do
    sign_in_as(users(:owner))
    get root_path
    assert_response :success
    assert_equal [ pantries(:main) ], assigns(:pantries).to_a
  end

  test "index scopes to the other pantry for a different owner" do
    sign_in_as(users(:second_pantry_owner))
    get root_path
    assert_response :success
    assert_equal [ pantries(:second) ], assigns(:pantries).to_a
  end

  test "index shows the same pantry to every member regardless of role" do
    sign_in_as(users(:admin))
    get root_path
    assert_equal [ pantries(:main) ], assigns(:pantries).to_a

    delete session_path
    sign_in_as(users(:staff))
    get root_path
    assert_equal [ pantries(:main) ], assigns(:pantries).to_a
  end

  test "index is empty (but still 200) for a user with no pantry membership" do
    sign_in_as(users(:no_pantry_user))
    get root_path
    assert_response :success
    assert_empty assigns(:pantries)
  end

  test "index is empty for a site admin with no pantry membership" do
    sign_in_as(users(:site_admin_user))
    get root_path
    assert_response :success
    assert_empty assigns(:pantries)
  end

  # ---------------------------------------------------------------------
  # new / create
  # ---------------------------------------------------------------------

  test "new requires authentication" do
    get new_pantry_path
    assert_redirected_to new_session_path
  end

  test "new renders for an authenticated user" do
    sign_in_as(users(:owner))
    get new_pantry_path
    assert_response :success
  end

  test "create requires authentication and does not create a pantry" do
    assert_no_difference("Pantry.unscoped.count") do
      post pantry_index_path, params: { pantry: { name: "Nope", address: "1 Nowhere" } }
    end
    assert_redirected_to new_session_path
  end

  test "create makes a new pantry and auto-assigns the creator as owner" do
    sign_in_as(users(:no_pantry_user))

    assert_difference("Pantry.unscoped.count", 1) do
      post pantry_index_path, params: { pantry: { name: "Third Pantry", address: "1 New St" } }
    end

    new_pantry = Pantry.unscoped.find_by(name: "Third Pantry")
    assert_redirected_to dashboard_index_path(pantry_id: new_pantry.id)
    assert_equal "Pantry Created!", flash[:notice]
    follow_redirect!
    assert_response :success

    membership = PantriesUser.find_by(user_id: users(:no_pantry_user).id, pantry_id: new_pantry.id)
    assert membership.present?
    assert_equal "owner", membership.role
  end

  test "create succeeds even with blank name/address since Pantry has no validations" do
    sign_in_as(users(:owner))

    assert_difference("Pantry.unscoped.count", 1) do
      post pantry_index_path, params: { pantry: { name: "", address: "" } }
    end
    assert_response :redirect
  end

  test "create without a pantry param raises a bad request instead of crashing silently" do
    sign_in_as(users(:owner))
    assert_no_difference("Pantry.unscoped.count") do
      post pantry_index_path, params: {}
    end
    assert_response :bad_request
  end

  # ---------------------------------------------------------------------
  # edit / update
  # ---------------------------------------------------------------------

  test "edit requires authentication" do
    get edit_pantry_path(id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "edit succeeds for the owner of the pantry" do
    sign_in_as(users(:owner))
    get edit_pantry_path(id: pantries(:main).id)
    assert_response :success
  end

  test "edit succeeds for a plain staff member too (no role enforcement)" do
    sign_in_as(users(:staff))
    get edit_pantry_path(id: pantries(:main).id)
    assert_response :success
  end

  test "edit 404s for a pantry the user does not belong to" do
    # ActiveRecord::RecordNotFound is registered in Rails' default
    # rescue_responses map (see activerecord/lib/active_record/railtie.rb), so
    # with config.action_dispatch.show_exceptions = :rescuable (test.rb) this
    # renders a 404 response rather than raising up into the test.
    sign_in_as(users(:owner))
    get edit_pantry_path(id: pantries(:second).id)
    assert_response :not_found
  end

  test "edit 404s for a user with no pantry membership at all" do
    sign_in_as(users(:no_pantry_user))
    get edit_pantry_path(id: pantries(:main).id)
    assert_response :not_found
  end

  test "update persists changes and redirects to the dashboard" do
    sign_in_as(users(:owner))
    patch pantry_path(id: pantries(:main).id), params: { pantry: { name: "Updated Main Pantry", address: "999 New Address" } }

    assert_redirected_to dashboard_index_path(pantry_id: pantries(:main).id)
    assert_equal "Pantry Updated!", flash[:notice]

    pantries(:main).reload
    assert_equal "Updated Main Pantry", pantries(:main).name
    assert_equal "999 New Address", pantries(:main).address
  end

  test "update requires authentication" do
    patch pantry_path(id: pantries(:main).id), params: { pantry: { name: "Hacked" } }
    assert_redirected_to new_session_path
    pantries(:main).reload
    assert_not_equal "Hacked", pantries(:main).name
  end

  test "MULTI-TENANCY: update 404s for a pantry the user does not belong to" do
    sign_in_as(users(:second_pantry_owner)) # owner of :second, not :main

    patch pantry_path(id: pantries(:main).id), params: { pantry: { name: "Hacked" } }

    assert_response :not_found
    assert_not_equal "Hacked", pantries(:main).reload.name
  end

  test "MULTI-TENANCY: update 404s for a user with no pantry membership at all" do
    sign_in_as(users(:no_pantry_user))

    patch pantry_path(id: pantries(:main).id), params: { pantry: { name: "Hacked" } }

    assert_response :not_found
    assert_not_equal "Hacked", pantries(:main).reload.name
  end

  # ---------------------------------------------------------------------
  # users / add_user / remove_user
  # ---------------------------------------------------------------------

  test "users requires authentication" do
    get pantry_users_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "users lists every member of the pantry for the owner" do
    sign_in_as(users(:owner))
    get pantry_users_path(pantry_id: pantries(:main).id)
    assert_response :success
    usernames = assigns(:users).map(&:username)
    assert_includes usernames, users(:owner).username
    assert_includes usernames, users(:admin).username
    assert_includes usernames, users(:staff).username
  end

  test "users crashes for a user who is not a member of the target pantry (no admin_only! gate, no nil guard)" do
    sign_in_as(users(:no_pantry_user))
    # ApplicationController#set_pantry does Pantry.find_by(id: params[:pantry_id]),
    # but Pantry's default_scope filters by Current.user's own memberships, so a
    # non-member never resolves Current.pantry, leaving it nil. PantryController#users
    # then calls Current.pantry.users with no nil check -> NoMethodError.
    assert_raises(NoMethodError) do
      get pantry_users_path(pantry_id: pantries(:main).id)
    end
  end

  test "a plain staff member can add and remove pantry users (admin_only! gap)" do
    sign_in_as(users(:staff))

    assert_difference("PantriesUser.count", 1) do
      post pantry_add_user_path(pantry_id: pantries(:main).id), params: { username: users(:no_pantry_user).username }
    end
    assert_redirected_to pantry_users_path(pantry_id: pantries(:main).id)
    assert_equal "Added user.", flash[:notice]
    assert PantriesUser.exists?(user_id: users(:no_pantry_user).id, pantry_id: pantries(:main).id)

    assert_difference("PantriesUser.count", -1) do
      get pantry_remove_user_path(pantry_id: pantries(:main).id), params: { username: users(:no_pantry_user).username }
    end
    assert_redirected_to pantry_users_path(pantry_id: pantries(:main).id)
    assert_equal "Removed user.", flash[:notice]
    assert_not PantriesUser.exists?(user_id: users(:no_pantry_user).id, pantry_id: pantries(:main).id)
  end

  test "add_user with an unknown username fails gracefully without creating a membership" do
    sign_in_as(users(:owner))
    assert_no_difference("PantriesUser.count") do
      post pantry_add_user_path(pantry_id: pantries(:main).id), params: { username: "totally-does-not-exist" }
    end
    assert_redirected_to pantry_users_path(pantry_id: pantries(:main).id)
    assert_equal "Cannot find user with the given username.", flash[:alert]
  end

  test "add_user can add a user who already belongs to a different pantry (cross-pantry, no isolation check)" do
    sign_in_as(users(:owner))
    assert_difference("PantriesUser.count", 1) do
      post pantry_add_user_path(pantry_id: pantries(:main).id), params: { username: users(:second_pantry_owner).username }
    end
    membership = PantriesUser.find_by(user_id: users(:second_pantry_owner).id, pantry_id: pantries(:main).id)
    assert membership.present?
    assert_equal "staff", membership.role # default enum value, add_user does not set a role
  end

  test "remove_user with an unknown username fails gracefully" do
    sign_in_as(users(:owner))
    assert_no_difference("PantriesUser.count") do
      get pantry_remove_user_path(pantry_id: pantries(:main).id), params: { username: "totally-does-not-exist" }
    end
    assert_redirected_to pantry_users_path(pantry_id: pantries(:main).id)
    assert_equal "Cannot find user with the given username.", flash[:alert]
  end

  test "remove_user removes an existing member" do
    sign_in_as(users(:owner))
    assert_difference("PantriesUser.count", -1) do
      get pantry_remove_user_path(pantry_id: pantries(:main).id), params: { username: users(:staff).username }
    end
    assert_not PantriesUser.exists?(user_id: users(:staff).id, pantry_id: pantries(:main).id)
  end
end
