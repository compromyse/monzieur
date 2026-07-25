# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Pantrie does

Pantrie tracks clients and visits for a food pantry, and supports multiple pantries in a single installation (the app is mid-rename from "Monzieur" to "Pantrie" — some internal references still say the old name).

A `Pantry` is the tenant boundary. `Current.pantry` is set per-request from the `:pantry_id` route segment (every non-admin route is nested under `scope ":pantry_id"`), and `Client`, `Visit`, and `HouseholdMember` are automatically scoped to it via `default_scope`. Users can belong to multiple pantries, with a per-pantry role on `PantriesUser#role` (`staff` / `admin` / `owner`). A separate global `User#site_admin` boolean gates the cross-tenant `/admin` namespace, independent of any pantry role.

### Clients and visits

Each `Client` belongs to one pantry and has many `HouseholdMember`s (nested attributes on the client form) and many `Visit`s. `Client#member_counts` is a JSONB-backed typed store holding integer counts per household-member age bracket (`HouseholdMember::MEMBER_TYPES`), used for daily sign-in totals without querying `household_members` directly. Clients are looked up by `uuid` in most routes (not numeric `id`) — the exception is `qr`, which uses `id`.

Several client actions render **printable documents**, not app UI: `agreement`, `tefap_attestation`, `intake_form`, and `qr` (a printable label), plus `visits#daily_signin`. These use the `pdf`/`qr` layouts and are self-contained HTML with embedded `<style>` blocks — see DESIGN.md's "Out of scope" section.

### Bulk operations

- CSV import (`ImportsController` → `lib/import.rb`) bulk-creates clients + household members from two paired CSVs via `activerecord-import`.
- Bulk blank intake forms (`BulkController#intake_form`) render one printable intake form per existing client.

## Quick reference

- Dev environment & commands: `docs/dev-environment.md`
- Auth & authorization: `docs/architecture/auth.md`
- Multi-tenancy (`Current.pantry`, scoping): `docs/architecture/multi-tenancy.md`
- Clients, visits, PDF documents: `docs/architecture/clients.md`
- Site admin panel: `docs/architecture/admin.md`
- Views, design system, partials: `docs/architecture/views.md`
- UI design rules: `DESIGN.md`
- Deployment: `DEPLOY.md`
- Commit policy: see Commits section below
- Testing policy: see Testing section below
- Updating docs: see Documentation section below

## Commits

Do not include a Co-Authored-By line in commit messages.

Write commit messages with a subject line and a body. The body should explain what changed and why — two to three sentences minimum. One-line subjects alone are not enough.

## Testing

There is currently no test suite in this app (no `test/` directory). Don't assume tests exist or can be run — verify behavior by starting the app (`bin/dev`) and exercising the affected flow manually. If you add a test framework or the first tests, update this section with the run command.

## Documentation

When making changes, update the relevant `docs/` file(s) before committing. Keep docs current — stale docs are worse than none.

## Stack

Rails 8.1 · PostgreSQL (local Unix socket at `pgdata/`) · HAML · Tailwind CSS v4 · Simple Form · Nix flakes

Always set `PGDATA=$(pwd)/pgdata` when running Rails commands. Run the app with `bin/dev` (Rails server + Tailwind watcher via foreman).
