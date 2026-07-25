# Authentication & Authorization

## Authentication

Custom session-based auth using `has_secure_password` (bcrypt). No Devise, no email — auth is username/password only (the app migrated off email-based auth; see migration `20251031215930_drop_email_address_and_add_username_to_users.rb`).

- `SessionsController` — login/logout at `/session` (new/create/destroy); `allow_unauthenticated_access only: %i[new create]`
- `UsersController` — self-serve signup at `/:pantry_id/users/new`; also `allow_unauthenticated_access`. Any visitor can create a `User` account — there's no invite/admin gating at the `User` level. Pantry membership is separate (see below).
- `Authentication` concern (`app/controllers/concerns/authentication.rb`) — included by `ApplicationController`, applies `require_authentication` as a default `before_action`.
- Session id is stored in a **signed, permanent, httponly, `same_site: :lax`** cookie, looked up against the `sessions` table (DB-backed, no expiry, no token rotation — a session lives until explicitly destroyed).
- `Current.user` is derived by delegation from `Current.session.user` (`app/models/current.rb`).
- Both `SessionsController#create` and `UsersController#create` are rate-limited to 10 attempts / 3 minutes.

## Authorization — two independent layers

### 1. Per-pantry role

```
User
 ├── has_many :pantries_user       (join: user_id, pantry_id, role)
 └── has_many :pantries, through: :pantries_user
```

`PantriesUser#role` is an enum (`staff` (0) / `admin` (1) / `owner` (2)), unique per `(user_id, pantry_id)`. `User#admin?` and `User#owner?` read `Current.pantries_user.role` — i.e. the role of the current user **within the currently-selected pantry**, not a global attribute. These will raise if `Current.pantries_user` is nil (no pantry selected).

A pantry's creator automatically becomes its `owner` via `Pantry#assign_user` (an `after_create` callback).

**Known gap**: `ApplicationController#admin_only!` exists (`redirect_to root_path, alert: 'Admin access only!'` if not `Current.user.admin?`) but is not currently wired into any `before_action`. Nothing in `PantryController` (`add_user`, `remove_user`, `edit`, `update`) or elsewhere actually enforces the staff/admin/owner tiers yet — any authenticated pantry member can currently hit those actions. Don't assume role checks are enforced just because the schema and model support them.

### 2. Global site admin

`User#site_admin` is a separate boolean column, unrelated to any pantry role. It's checked in exactly one place: `Admin::BaseController#authorize_admin!` (`Current.user.site_admin?`), gating the entire `/admin` namespace. `Admin::BaseController` does **not** inherit from `ApplicationController` — it's a sibling base class that includes `Authentication` directly and skips `set_pantry`/`set_pantries_user`, since the admin panel is cross-tenant.

## Post-login routing

There is no location-picker/redirect logic analogous to a multi-app dashboard — after login, `after_authentication_url` sends the user back to whatever URL they originally requested (stored in `session[:return_to_after_authenticating]`), or `root_path` (`PantryController#index`, the pantry picker) otherwise.
