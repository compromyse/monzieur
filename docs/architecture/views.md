# Views

All views are HAML. Tailwind CSS v4 compiled by `tailwindcss-rails` to `app/assets/builds/tailwind.css`.

## Design

Full design system: `DESIGN.md` at the project root. Summary:

- Internal staff/volunteer tool — flat, minimal, black/white/gray only, no shadows/rounded corners/gradients
- `text-lg` minimum on interactive elements, thick `border-2 border-gray-900` as the primary visual separator
- One primary action per page (a filled `bg-gray-900` button); everything else is an underlined text link
- **Printable documents are excluded** — `clients/agreement.html.erb`, `clients/tefap_attestation.html.erb`, `clients/_intake_form.html.erb`, `clients/qr.html.haml`, `visits/daily_signin.html.erb`, `bulk/intake_form.html.haml`/`_new_page.html.haml` keep their own embedded `<style>` blocks and are not styled with Tailwind. See `docs/architecture/clients.md` for what each renders.

## Layouts

- `application` — default layout for logged-in app screens; renders `_navbar` and flash messages, loads the Tailwind stylesheet.
- `admin` — used only by `Admin::BaseController` subclasses; separate minimal nav, no pantry context (cross-tenant).
- `pdf` / `qr` — minimal, used only by the printable-document actions listed above; no Tailwind stylesheet, no nav — those views are fully self-styled.

## Client search (Tom Select)

`app/views/dashboard/index.html.haml` uses the Tom Select JS library (loaded from CDN, not bundled) for the client search box. Its default theme is overridden in `app/assets/stylesheets/application.css` with plain CSS targeting Tom Select's own class names (`.ts-control`, `.ts-dropdown`, etc.), since those aren't reachable with Tailwind utility classes. If you touch the search UI, restyle through that CSS block rather than adding Tailwind classes directly to Tom Select-generated markup — Tom Select controls its own DOM structure at runtime.

## Shared partials

- `app/views/application/_navbar.html.haml` — top nav for all logged-in, non-admin pages.
- `app/views/clients/_form.html.haml` / `_form_household_members.html.haml` — client create/edit form, including the nested household-members table (driven by the `nested-fields` Stimulus controller).
- `app/views/pantry/_form.html.haml` — pantry create/edit form fields.

## Pagination

No pagination gem is currently used anywhere in the app (unlike some sibling projects that use Pagy) — client/visit lists are not yet paginated. If a list grows large enough to need it, `pagy` is the established choice in this codebase family.
