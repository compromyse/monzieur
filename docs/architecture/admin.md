# Admin Panel

`Admin::BaseController` (`app/controllers/admin/base_controller.rb`) — does **not** inherit from `ApplicationController`. It's a sibling base class that includes the `Authentication` concern directly and applies `before_action :authorize_admin!`, which requires `Current.user.site_admin?` (a global boolean, unrelated to any per-pantry role — see `docs/architecture/auth.md`). It does not run `set_pantry`/`set_pantries_user`, since this namespace is cross-tenant by design. Uses the `admin` layout.

## Current state

`Admin::DashboardController#index` (`admin_index_path`, the only route in the namespace today) shows two counts:
- Total household members across all pantries (`HouseholdMember.unscoped.count`)
- Total pantries (`Pantry.all.count`)

The pantry count is scoped by `Pantry`'s own `default_scope` (filtered by `Current.user`, see `docs/architecture/multi-tenancy.md`), not `.unscoped`, so it will likely undercount unless the site-admin user happens to belong to every pantry — a known gap, not yet fixed.

## Adding admin resources

There's no established pattern yet beyond the dashboard — if adding CRUD for a cross-tenant resource (e.g. managing `site_admin` flags, or a pantry list/delete view), follow `Admin::DashboardController`'s inheritance from `Admin::BaseController` and add routes under the existing `namespace :admin do ... end` block in `config/routes.rb`.
