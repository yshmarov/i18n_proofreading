# AGENTS.md

Instructions for coding agents. Two audiences:

- **[Installing i18n_proofreading into a Rails app](#installing-into-a-rails-app)** — you are working in a host app and were asked to add in-context translation review or a way for someone to suggest better wording.
- **[Working on the gem itself](#working-on-the-gem-itself)** — you are working in this repository.

Requirements: Ruby >= 3.2, Rails >= 7.1. The widget needs the CSRF token from `csrf_meta_tags`, which a standard Rails layout already has.

**Read this first: the gem never writes to your locale files, and it is not a production tool.** Both are deliberate, and both are covered below.

If you are in a host app and this file is not in front of you, it ships inside the gem: `cat "$(bundle show i18n_proofreading)/AGENTS.md"`.

---

## Installing into a Rails app

### 1. Install

```bash
bundle add i18n_proofreading
bin/rails generate i18n_proofreading:install
bin/rails db:migrate
```

The generator writes `config/initializers/i18n_proofreading.rb`, one migration (`i18n_proofreading_suggestions`), and mounts the engine. Read the initializer it wrote — every option is documented there in comments, and it is the source of truth over any summary of it, including this file.

### 2. There is no step 2 — do not edit the layout

The widget injects itself into HTML responses through a Rack middleware, so **no layout change is needed**. Boot the app in development and look for the **"Suggest edits"** pill bottom-left. Click it, then click any text; `Esc` exits.

Only if the host prefers to place it explicitly:

```ruby
config.auto_inject = false
```

```erb
<%= i18n_proofreading_tag %>
```

Do not do both. And do not go looking for a missing `<%= … %>` when the pill does not appear — auto-injection is the default, so the cause is almost always the environment gate below.

### 3. Before deploying: understand the two gates

**a. Environments.** The tool is active only in `config.enabled_environments`, which defaults to `%w[development staging]`. In every other environment it does nothing at all: no key markers, no endpoint, and the I18n backend patch that marks keys is never even prepended. **Do not add `production` to that list to "let the client review the live site."** Marking every translated string in production is a user-visible change to every page, and the review endpoint is not built to be public.

**b. The dashboard.** `/i18n_proofreading` defaults to **development only** and is independent of the widget gates, so a maintainer can triage from production while the widget stays off. It fails closed:

```ruby
config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
```

> **`enabled`, `authorize_admin` and `current_user` receive the raw `request`, not a controller.** Writing `->(request) { current_user }` is the most common mistake here — that method does not exist in this scope. Resolve the user *from the request*: Warden env, a signed cookie, `Current.user` if middleware already set it. `author_label` is the exception: it receives whatever `current_user` returned.

### 4. Verify

```bash
bin/rails routes | grep i18n_proofreading    # engine mounted
bin/rails i18n_proofreading:seed_demo        # optional sample suggestions, idempotent
```

Then in development: load a page, confirm the pill appears bottom-left, suggest a change to any string, and read it back at `/i18n_proofreading`.

### The gem does not apply suggestions, and that is the point

A suggestion is a row: the i18n key, the old value, the proposal, an optional comment, a locale, and a status (`pending` / `applied` / `rejected`). Nothing in the gem edits `config/locales/*.yml`, and **the dashboard is read-only — `index` and `show`, with no update or destroy action.** Applying a wording change means a human (or your own tooling) editing the YAML and committing it.

So: **do not ask this gem to rewrite locale files, and do not build a "click to apply" button expecting an endpoint to exist.** If the app wants status bookkeeping, do it deliberately from your own code or the console — the enum is prefixed:

```ruby
I18nProofreading::Suggestion.status_pending.find(id).status_applied!
```

If you are asked to automate applying suggestions, that is host-app work: read the rows, write the YAML, review the diff in a pull request. Treat the suggestion table as an inbox, not as the source of truth for translations.

### Turning suggest mode on from your own UI

The pill is one way; a link is another, and the choice is remembered in a cookie so the rest of the app stays in suggest mode:

```
?i18n_proofreading=true    # on
?i18n_proofreading=false   # off
```

`config.show_pill = false` hides the pill, `config.pill_label` overrides its text (nil = the localized `i18n_proofreading.pill` key), and `config.toggle_param` renames the parameter.

### Do not

- **Do not add `production` to `enabled_environments`** (see above).
- **Do not copy the widget JavaScript into `app/javascript`, or add a `<script>` tag for it.** The middleware injects what is needed and the engine serves the code same-origin — which is what lets it run under a nonce-based CSP, including `strict-dynamic`, across Turbo body swaps.
- **Do not edit the layout** for the default install — auto-injection is the default.
- **Do not expect the gem to write YAML** (see above).
- **Do not set config outside the initializer.** `rate_limit` in particular is read once when the controller class loads; assigning config per-request mutates it process-wide.

### Configuration worth knowing

Everything is optional; a fresh install works with zero config in development. Full list with comments is in the generated initializer.

| Option | Default | Note |
| --- | --- | --- |
| `enabled_environments` | `%w[development staging]` | The hard gate. Never add production |
| `enabled` | everyone | Per-request gate on top of the environment check |
| `authorize_admin` | development only | **Who can read the dashboard.** Independent of the above |
| `base_controller_class` | `ActionController::Base` | Controller the dashboard inherits. Name your admin's and it adopts that layout, helpers, authentication and request context. Public endpoints never inherit it. |
| `admin_layout` | `i18n_proofreading/application` | Render the dashboard in your admin shell |
| `current_user` | `nil` | Receives the request |
| `author_label` | email, else `to_s` | Receives the user |
| `available_locales` | `I18n.available_locales` | Callable; validates what a suggestion may target |
| `auto_inject` | `true` | `false` = place `i18n_proofreading_tag` yourself |
| `show_pill`, `pill_label` | `true`, localized | Hide the pill and use `?i18n_proofreading=true` instead |
| `toggle_param` | `"i18n_proofreading"` | Rename the query parameter |
| `rate_limit` | `{ to: 30, within: 60 }` | Rails 7.2+; ignored on 7.1. `nil` disables |
| `mount_path` | `"/i18n_proofreading"` | Keep in sync with the `mount` line |
| `on_submit` | no-op | Runs inline after save — Slack, email, a ticket |

The tool's own UI ships in 26 languages, RTL mirrored, and follows system light/dark.

### Common failure modes

| Symptom | Cause |
| --- | --- |
| `NameError` for one of your own helpers in the dashboard | `isolate_namespace` scopes `helper` to the engine. Use `config.base_controller_class` so the dashboard inherits your helpers, rather than `admin_layout` alone. |
| No pill, no outlines | The environment is not in `enabled_environments` (this is the usual one), or `config.enabled` returned false, or `show_pill = false` |
| Pill appears but no strings are outlined | The I18n backend patch is only prepended in an enabled environment at boot — check you are actually in development/staging, and restart after changing the setting |
| `/i18n_proofreading` returns a 403 | `authorize_admin` still at its development-only default |
| Suggestions rejected with an invalid-token error | The layout is missing `csrf_meta_tags` |
| A suggestion is rejected as an invalid locale | It must be in `config.available_locales` |
| Nothing changes in the app after a suggestion is accepted | Expected. The gem never writes locale files — a human edits the YAML |
| `undefined local variable current_user` in the initializer | A gate lambda treated its argument as a controller. It is a `request` |

---

## One family

`testimonials`, `ideasbugs`, `livechat`, `product_tours` are the sibling engines. Same install shape, same host hooks (`base_controller_class`, `admin_layout`), same scoped dashboard CSS, same `primary_key_type`-aware migrations — so what you learn here transfers.

## Working on the gem itself

```bash
bundle exec rake test            # minitest, dummy app under test/dummy
bundle exec rubocop              # must be clean
BUNDLE_GEMFILE=gemfiles/rails_7.1.gemfile bundle exec rake test   # 7.1, 7.2, 8.0, 8.1 in gemfiles/
```

Layout: `app/` controller, `Suggestion`, dashboard views · `lib/i18n_proofreading/` config, middleware, the I18n marking backend, widget JS, seeds, engine · `lib/generators/i18n_proofreading/install/` the one generator · `config/locales/` 26 locales · `test/` minitest with `test/dummy` as the host app.

Conventions this codebase holds to — follow them rather than the first thing that works:

- **Production carries none of it.** The marking backend is prepended in `after_initialize` only when `environment_enabled?`, so a production boot never even patches I18n. Anything new must keep that property: no markers, no endpoint, no patch outside the enabled environments.
- **The tool never writes to the host's locale files.** That is why there is deliberately no update or destroy route, and why the dashboard is read-only. Do not add an "apply" action that edits YAML.
- **The widget is injected by middleware and served same-origin**, which is what keeps it working under a nonce-based CSP with `strict-dynamic` across Turbo body swaps. Do not inline it.
- **Key marking must degrade to plain strings.** A host that reads translations outside a request, or in an environment where the tool is off, has to get ordinary values back.
- Every user-facing change bumps `lib/i18n_proofreading/version.rb` and adds a `CHANGELOG.md` entry (Keep a Changelog format) that says what it costs, not only what it adds.
- Commit messages are prose that explains the tradeoff — read `git log` before writing one.
