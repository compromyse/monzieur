# Dev Environment

Nix flakes — always pre-configured when Claude runs here. No need to run `direnv allow` or `nix develop`.

## PostgreSQL

Runs locally inside the project at `pgdata/`. Connect via Unix socket, not TCP. Always set `PGDATA=$(pwd)/pgdata` when running Rails commands outside the `dev` wrapper.

```
pg-setup   # initialise pgdata/ (first time only)
pg-start   # start postgres
pg-stop    # stop postgres
dev        # pg-start + tmux session "monzieur" + pg-stop on exit
```

## Starting the app

```bash
bin/dev    # Rails server + Tailwind watcher via foreman (Procfile.dev)
```

## Common commands

```bash
PGDATA=$(pwd)/pgdata rails db:migrate
PGDATA=$(pwd)/pgdata rails db:seed
PGDATA=$(pwd)/pgdata rails db:migrate:status
PGDATA=$(pwd)/pgdata rails routes
PGDATA=$(pwd)/pgdata rails runner '<ruby>'
bundle exec brakeman
bundle exec rubocop
bundle exec bundler-audit
```

Test database is `monzieur_test` (a separate database from development — see `config/database.yml`). Run with `PGDATA=$(pwd)/pgdata rails test`. See the Testing section in `CLAUDE.md` for fixture/`Current` conventions.

## Git hooks

`git config core.hooksPath .githooks` is set for this repo. `.githooks/pre-commit` and `.githooks/pre-push` both run the full test suite and abort the commit/push on failure.

## Tailwind

Styling is Tailwind CSS v4 via the `tailwindcss-rails` gem — no Node/npm involved, it vendors a native `tailwindcss` binary per platform. The entrypoint is `app/assets/tailwind/application.css` (just `@import "tailwindcss";`, no custom theme). `bin/dev` runs `rails tailwindcss:watch` alongside the Rails server, recompiling `app/assets/builds/tailwind.css` on every view change automatically — no separate build step needed during development. See `DESIGN.md` for the actual design rules.
