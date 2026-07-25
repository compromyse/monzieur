# Multi-tenancy

`Pantry` is the tenant boundary. This is the most important pattern to understand correctly before touching `Client`, `Visit`, or `HouseholdMember` — nearly all query scoping is implicit, not explicit in controller code.

## How tenant scoping works

1. Every non-admin route is nested under `scope ":pantry_id"` in `config/routes.rb` (e.g. `/:pantry_id/clients/...`).
2. `ApplicationController#set_pantry` (a `before_action`) sets `Current.pantry ||= Pantry.find_by(id: params[:pantry_id])`.
3. `ApplicationController#set_pantries_user` then sets `Current.pantries_user` to the `PantriesUser` row for `(Current.user, Current.pantry)` — used for role checks (see `docs/architecture/auth.md`).
4. `Client`, `Visit`, and `HouseholdMember` each declare:
   ```ruby
   default_scope { where(pantry_id: Current.pantry&.id).distinct }
   ```
   So **every ActiveRecord query against these three models is automatically scoped to the current pantry** — controllers never need to add `.where(pantry_id: ...)` manually. If `Current.pantry` is nil, the scope becomes `where(pantry_id: nil)`, which returns zero rows (since `pantry_id` is `NOT NULL` in the DB) rather than raising or leaking cross-tenant data.
5. `before_validation :assign_pantry, on: :create` force-sets `self.pantry = Current.pantry` on `Client` and `Visit` (unconditional overwrite). `HouseholdMember#assign_pantry` uses `self.pantry ||= Current.pantry` instead (only sets if not already set) — a subtly different guard than its siblings, though it doesn't matter in practice since nested household-member creation via a `Client` form doesn't pre-set pantry.
6. `ApplicationController#default_url_options` auto-injects `pantry_id: Current.pantry&.id` into every generated URL, so views/redirects don't need to pass it explicitly.

## `Pantry` itself is scoped differently

`Pantry` has its own `default_scope`, but scoped by **user**, not by itself (naturally — pantry is the tenant boundary, it can't scope itself):

```ruby
default_scope { joins(:pantries_user).where(pantries_user: { user_id: Current.user&.id }).distinct }
```

So `Pantry.all` / `Pantry.find` only ever return pantries the *currently logged-in user* belongs to. This is what powers the pantry picker (`PantryController#index`, the root page) — a user with multiple pantries sees all of them; a user with one sees just that one.

## Bypassing tenant scoping

Because these are `default_scope`s (not named scopes), any code that legitimately needs to see across all tenants must call `.unscoped` explicitly. The only place this happens today is `Admin::DashboardController#index` (`HouseholdMember.unscoped.count`) for the cross-tenant site-admin dashboard.

**Known gap**: that same action does `Pantry.all.count` (not `Pantry.unscoped.count`) for its pantry total — since `Pantry`'s own `default_scope` filters by `Current.user`, this likely undercounts unless the site-admin user happens to belong to every pantry. Worth fixing if the admin dashboard's numbers look wrong, but documenting current behavior here rather than silently changing it.

## Adding a new tenant-scoped model

Follow the `Client`/`Visit` pattern: add a `pantry_id` FK column (`NOT NULL`), `belongs_to :pantry`, `before_validation :assign_pantry, on: :create` (unconditional, matching `Client`/`Visit` rather than `HouseholdMember`'s `||=` unless you have a specific reason not to), and `default_scope { where(pantry_id: Current.pantry&.id).distinct }`.
