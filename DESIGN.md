# DESIGN.md

This document describes the visual design system for Pantrie. Follow it exactly when building or modifying any in-app UI. Do not introduce new patterns without updating this document.

## Philosophy

Pantrie is used by pantry staff and volunteers for repeated, fast daily tasks — registering clients, logging visits, managing pantry members. It is not aimed at the food-pantry clients themselves; the people using this UI are staff, but shift volunteers vary widely in computer comfort and are often moving quickly during a distribution. Every decision should reduce friction and keystrokes:

- Show only what is needed for the current task. Remove anything decorative.
- Fewer elements on screen is always better.
- When in doubt, make it bigger and plainer.

---

## Out of scope

The following views render **self-contained printed documents** (client agreement, TEFAP attestation, intake forms, QR labels, the daily sign-in sheet) — official/government-facing paperwork with their own embedded `<style>` blocks and the agency's brand color (`#a33a1a`). They are intentionally **not** part of this design system and should not be converted to Tailwind:

- `app/views/clients/agreement.html.erb`
- `app/views/clients/tefap_attestation.html.erb`
- `app/views/clients/_intake_form.html.erb` / `intake_form.html.haml`
- `app/views/clients/qr.html.haml`
- `app/views/visits/daily_signin.html.erb`
- `app/views/bulk/intake_form.html.haml` / `_new_page.html.haml`

Everything else — the in-app screens staff actually navigate — follows the system below.

---

## Colors

The palette is almost entirely black, white, and gray. Color is not used for decoration.

| Use | Value |
|---|---|
| Page background | `bg-white` |
| Primary text | `text-gray-900` |
| Secondary / muted text | `text-gray-500` |
| Borders | `border-gray-900` (interactive), `border-gray-400` (inputs), `border-gray-200` (dividers) |
| Primary button | `bg-gray-900 text-white hover:bg-gray-700` |
| Destructive action | `text-red-700 underline` (no background) |
| Flash notice | `bg-green-100 border-green-300 text-green-900` |
| Flash alert / inline warning banner | `bg-red-100 border-red-300 text-red-900` |

Do not introduce new colors. Do not use colored backgrounds for cards, sections, or labels. Inline warning banners (e.g. the household-member-count mismatch on a client's page) reuse the flash alert treatment rather than inventing a one-off color.

---

## Typography

| Element | Classes |
|---|---|
| Page title (`h1`) | `text-3xl font-bold text-gray-900` |
| Section label | `text-sm font-semibold text-gray-500 uppercase tracking-widest` |
| Body / field labels | `text-xl font-medium text-gray-900` |
| Secondary info | `text-lg text-gray-500` |
| Inline metadata | `text-lg text-gray-600` |

Minimum font size for any interactive element is `text-lg`. Never go smaller on buttons, labels, or links.

---

## Layout

- Page padding: `px-6 py-8` (applied by the layout, not individual views)
- Max width on forms: `max-w-lg`
- Max width on content pages: none by default — let content breathe
- Vertical spacing between major sections: `space-y-10` or `mb-8`
- Vertical spacing between list rows: `space-y-2`

---

## Navigation

The nav bar is rendered by the layout for any logged-in user (`app/views/application/_navbar.html.haml`). It contains:
- App name ("Pantrie") as a bold link to root — `text-2xl font-bold`
- Current user's username — `text-lg text-gray-700`
- Log out — underlined text link, no button styling

The nav bar uses a thick bottom border (`border-b-2 border-gray-900`) as the only separator. No background color, no shadow.

---

## Buttons and Actions

### Primary button (one per page)
```haml
= f.submit "Label", class: "px-6 py-3 text-lg font-bold text-white bg-gray-900 hover:bg-gray-700 cursor-pointer transition-colors"
= link_to "Label", path, class: "px-6 py-3 text-lg font-bold text-white bg-gray-900 hover:bg-gray-700 transition-colors"
```

### Secondary / cancel action
```haml
= link_to "Cancel", path, class: "px-6 py-3 text-lg font-medium text-gray-900 underline"
```

### Destructive action (remove / delete)
```haml
= link_to "Remove", path, data: { turbo_confirm: "Remove X?" }, class: "text-lg font-medium text-red-700 underline"
```

Rules:
- One primary action per page. Everything else is secondary.
- Destructive actions are underlined red text — never a filled red button.
- Confirm dialogs use plain language: "Remove X?" not "Are you sure you want to permanently delete X?"

---

## Navigation Rows (list items that link somewhere)

Used on the pantry picker, staff dashboard, and anywhere a user taps to navigate into a section.

```haml
= link_to path, class: "flex items-center justify-between px-6 py-5 border-2 border-gray-900 hover:bg-gray-100 transition-colors" do
  %span.text-2xl.font-bold.text-gray-900 Label
  %span.text-gray-500 →
```

- Thick border on all four sides
- Large bold label on the left, `→` on the right
- Hover fills with `bg-gray-100`
- No icons, no sublabels unless essential

---

## List Rows (non-navigable, e.g. pantry members)

```haml
.flex.items-center.justify-between.px-6.py-5.border-2.border-gray-900
  .space-y-1
    %p.text-2xl.font-bold.text-gray-900= item.name
    %p.text-lg.text-gray-500= item.secondary_info
  = link_to "Remove", ..., class: "text-lg font-medium text-red-700 underline"
```

- Same padding and border as navigation rows
- Destructive action floated right, `shrink-0` to prevent wrapping
- Keep secondary info to one line where possible — join with ` · ` separator

---

## Forms

```haml
= simple_form_for @record, class: "space-y-8 max-w-lg" do |f|
  = f.input :field, label: "Label", label_html: { class: "block text-xl font-medium text-gray-900" },
      input_html: { class: "w-full px-4 py-3 text-xl border-2 border-gray-400 focus:border-gray-900 focus:outline-none" }
  .flex.gap-4
    = f.submit "Save", class: "px-6 py-3 text-lg font-bold text-white bg-gray-900 hover:bg-gray-700 cursor-pointer transition-colors"
    = link_to "Cancel", back_path, class: "px-6 py-3 text-lg font-medium text-gray-900 underline"
```

- `border-2 border-gray-400` on inputs, thickens to `border-gray-900` on focus
- No floating labels, no placeholder-only labels — always a visible label above the field
- Validation errors appear directly below the field in `text-lg text-red-700`
- Submit + Cancel always paired at the bottom with `flex gap-4`
- Checkboxes: `w-6 h-6 border-2 border-gray-400`
- Selects: `px-3 py-2 text-lg border-2 border-gray-400 bg-white`

---

## Tables

Used for pantry member lists, visit logs, and other tabular admin views.

```haml
%table.w-full.text-lg
  %thead
    %tr.border-b-2.border-gray-900
      %th.text-left.py-2 Column
  %tbody
    %tr.border-b.border-gray-200
      %td.py-3= value
```

- `border-b-2 border-gray-900` under the header row, `border-b border-gray-200` between body rows
- No zebra striping, no cell backgrounds

---

## Tom Select (client search)

The client search box on the staff dashboard (`app/views/dashboard/index.html.haml`) uses the Tom Select JS library, loaded from CDN. Its default theme is overridden with a small custom CSS block in `app/assets/stylesheets/application.css` so the control and dropdown match this system: square corners, `border-2 border-gray-400` (thickening to `border-gray-900` on focus), no box-shadow, `text-lg`. This is a targeted CSS override, not a library swap — Tom Select's own class names (`.ts-control`, `.ts-dropdown`, etc.) aren't reachable with Tailwind utility classes alone, so plain CSS is used there instead of `@apply`.

---

## What to avoid

- Shadows (`shadow`, `shadow-sm`, `shadow-lg`, etc.) — never
- Rounded corners (`rounded`, `rounded-xl`, `rounded-2xl`, etc.) — never
- Colored card backgrounds (`bg-blue-50`, `bg-green-50`, etc.) — never
- Badges and pills — avoid; use plain text with ` · ` separators instead
- Gradients — never
- Icons — avoid unless absolutely necessary; use text labels
- Hover color changes on non-interactive elements
- More than one visual hierarchy level per page (one `h1`, then flat content)
- Inline `style=` attributes for anything this document already covers (color, spacing, borders) — use the utility classes above instead
