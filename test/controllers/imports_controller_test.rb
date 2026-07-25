require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------
  # import_csv_form: plain rendered form, no logic
  # ---------------------------------------------------------------------

  test "import_csv_form requires authentication" do
    get import_csv_form_imports_path(pantry_id: pantries(:main).id)
    assert_redirected_to new_session_path
  end

  test "import_csv_form renders successfully for a signed-in pantry member" do
    sign_in_as(users(:owner))

    get import_csv_form_imports_path(pantry_id: pantries(:main).id)
    assert_response :success
  end

  # ---------------------------------------------------------------------
  # import_csv: reads the two uploaded CSVs and delegates to Import
  # ---------------------------------------------------------------------

  test "import_csv requires authentication" do
    post import_csv_imports_path(pantry_id: pantries(:main).id), params: {
      full_list: fixture_file_upload("import_full_list.csv", "text/csv"),
      clients: fixture_file_upload("import_clients.csv", "text/csv")
    }
    assert_redirected_to new_session_path
  end

  test "import_csv imports clients and household members from the uploaded CSVs" do
    sign_in_as(users(:owner))
    # Use .unscoped for the before/after counts: Current.pantry is a
    # request-local attribute that ActiveSupport::Executor clears after
    # every request completes (see active_support/railtie.rb's
    # `app.executor.to_complete { CurrentAttributes.clear_all }`), so it
    # isn't reliably set in the test process's own Current around the POST.
    before_count = Client.unscoped.count

    post import_csv_imports_path(pantry_id: pantries(:main).id), params: {
      full_list: fixture_file_upload("import_full_list.csv", "text/csv"),
      clients: fixture_file_upload("import_clients.csv", "text/csv")
    }

    assert_redirected_to import_csv_form_imports_path(pantry_id: pantries(:main).id)
    assert_equal "Imported 1 clients!", flash[:notice]

    after_count = Client.unscoped.count
    assert_equal 1, after_count - before_count

    imported = Client.unscoped.find_by(first_name: "Wanda", last_name: "Import")
    refute_nil imported
    assert_equal pantries(:main).id, imported.pantry_id
    assert_equal 1, imported.member_counts["toddler"]
    assert_equal 1, imported.member_counts["adult"]
    assert_equal 0, imported.member_counts["infant"]

    # imported.household_members would go through HouseholdMember's own
    # default_scope (filtered by Current.pantry), which is nil here for the
    # same reason as above -- query unscoped instead.
    members = HouseholdMember.unscoped.where(client_id: imported.id)
    assert_equal 2, members.count
    assert_equal [ "Vera", "Wesley" ], members.map(&:first_name).sort
    members.each do |member|
      assert_equal pantries(:main).id, member.pantry_id
    end
  end

  test "import_csv for a user outside the target pantry silently drops the import and blows up on redirect" do
    # Known-real gap, traced empirically (not guessed):
    #
    # 1. ApplicationController#set_pantry does
    #      Current.pantry ||= Pantry.find_by(id: params[:pantry_id])
    #    but Pantry's own default_scope filters by the *current user's*
    #    pantry memberships. second_pantry_owner isn't a member of :main,
    #    so Pantry.find_by(id: main.id) returns nil for them and
    #    Current.pantry stays nil for the whole request.
    #
    # 2. Import::change still builds Client.new(cl) objects, but with no
    #    Current.pantry to assign, every built Client fails the pantry
    #    presence validation. Client.import(final, recursive: true)
    #    validates by default and silently skips invalid records --
    #    nothing is persisted, no exception is raised there.
    #
    # 3. Import#import_from_csvs still `return final.count` (the number of
    #    rows it attempted), not the number actually inserted -- so the
    #    controller thinks the import succeeded.
    #
    # 4. The controller then does
    #      redirect_to import_csv_form_imports_path, notice: "Imported #{num} clients!"
    #    with no explicit pantry_id. ApplicationController#default_url_options
    #    fills in `pantry_id: Current.pantry&.id`, which is nil, and the
    #    route requires a pantry_id segment -- so URL generation itself
    #    raises ActionController::UrlGenerationError instead of ever
    #    reaching the user as a redirect.
    sign_in_as(users(:second_pantry_owner))
    before_count = Client.unscoped.count

    assert_raises(ActionController::UrlGenerationError) do
      post import_csv_imports_path(pantry_id: pantries(:main).id), params: {
        full_list: fixture_file_upload("import_full_list.csv", "text/csv"),
        clients: fixture_file_upload("import_clients.csv", "text/csv")
      }
    end

    after_count = Client.unscoped.count
    assert_equal before_count, after_count, "no client should actually have been persisted"
  end
end
