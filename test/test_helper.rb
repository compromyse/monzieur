ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Client, HouseholdMember, Visit, and Pantry all read Current.pantry / Current.user
    # in a default_scope (see docs/architecture/multi-tenancy.md). There's no request
    # cycle in model tests to populate Current automatically, so it can leak between
    # tests in the same worker process unless explicitly reset.
    teardown do
      Current.reset
    end

    # Log in as `user` and select `pantry` for integration/controller tests, exactly
    # like a real session: POST to the login form, matching the app's own auth flow.
    # Model tests that need Current.pantry / Current.user directly should set them
    # explicitly instead of using this helper.
    def sign_in_as(user, password: "password")
      post session_path, params: { username: user.username, password: password }
    end
  end
end
