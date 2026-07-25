# Clients, Household Members, Visits

## Client

`app/models/client.rb`. Belongs to a `Pantry` (see `docs/architecture/multi-tenancy.md`). Fields: `first_name`/`last_name` (`NOT NULL`, no application-level presence validation — only the DB constraint), `mobile_number`, `address`, `zipcode`, `notes` (default `""`), `uuid` (Postgres `uuid`, default `gen_random_uuid()`, unique — the public identifier used in most client routes instead of numeric `id`).

- `member_counts` — a JSONB column via `activerecord-typedstore`, one integer field per `HouseholdMember::MEMBER_TYPES` key (`infant`, `toddler`, `child`, `adult`, `senior`), each defaulting to 0. Lets a client aggregate household size directly without joining `household_members` — used by the daily sign-in sheet's totals.
- `accepts_nested_attributes_for :household_members, allow_destroy: true, reject_if: :all_blank` — the client form creates/edits/removes household members inline (see `app/javascript/controllers/nested_fields_controller.js` for the add/remove UI behavior).
- `name` → `"first_name last_name"`; `last_visit` → formatted date or `'-'`; `visit_history` → visits grouped by year → month name, used by the lazy-loaded turbo-frame on the client show page.

## HouseholdMember

`app/models/household_member.rb`. `MEMBER_TYPES` is the single source of truth for age-bracket categories (`infant: 'Infant (< 2)'`, etc.) — reused by `Client#member_counts` (typed-store keys), the CSV importer, and every place that renders these labels. `first_name`/`last_name` are `NOT NULL`, no presence validation beyond the DB constraint (same pattern as `Client`).

## Visit

`app/models/visit.rb`. Records one visit event: `belongs_to :client`, `belongs_to :user` (the staff member who logged it, set explicitly in `VisitsController#create` — not a model callback). `VisitsController#daily_signin` aggregates `member_counts` across all of a day's visits into per-bracket totals for the printed sign-in sheet.

## CSV import

`ImportsController#import_csv` → `lib/import.rb` (a plain Ruby class, not an ActiveRecord model). Takes two paired CSV uploads — a full household-member list and a "who's the primary client" list — reshapes matching rows into `Client.new(...)` with nested `HouseholdMember.new(...)` and a `member_counts` hash, then bulk-inserts via `Client.import(final, recursive: true)` (`activerecord-import` gem, `recursive: true` to insert the nested household members in the same pass).

## Printable documents (out of scope for the design system)

Several client/visit actions render **self-contained printed documents**, not app UI — see `DESIGN.md`'s "Out of scope" section for why they're excluded from the Tailwind design system:

| Action | Route | Purpose |
|---|---|---|
| `ClientsController#agreement` | `agreement_clients_path` | Single-pantry agreement letter |
| `ClientsController#tefap_attestation` | `tefap_attestation_clients_path` | TEFAP eligibility attestation form |
| `ClientsController#intake_form` | `intake_form_clients_path` | Single-client intake form |
| `BulkController#intake_form` | `intake_form_bulk_index_path` | Blank intake forms for every client in the pantry, one per printed page |
| `ClientsController#qr` | `qr_clients_path` | Printable QR label encoding the client's `uuid` (looked up by numeric `id`, unlike the other document actions which use `uuid` — a pre-existing inconsistency, not something to "fix" incidentally) |
| `VisitsController#daily_signin` | `daily_signin_visits_path` | Daily sign-in sheet with per-bracket totals |

`ClientsController` sets `layout 'pdf', only: [:intake_form, :tefap_attestation, :agreement]`; `BulkController` and `VisitsController#daily_signin` do the same. `qr` renders with the separate `qr` layout. Both layouts are intentionally minimal (no nav, no Tailwind stylesheet) since these views embed their own `<style>` blocks, including the agency's brand color `#a33a1a`.
