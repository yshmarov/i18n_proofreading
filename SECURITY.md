# Security policy

## Supported versions

Security fixes are released for the latest 1.x version. If a report also
affects the newest 0.x release, a backport may be published when the fix is
small and the affected application cannot upgrade immediately.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/yshmarov/i18n_proofreading/security/advisories/new)
and include the affected version, a minimal reproduction, impact, and any known
workaround. Credentials, session cookies, private application URLs, customer
text, and production database contents should not be included.

Public disclosure should wait until a fixed version is available and affected
users have had a reasonable opportunity to upgrade.

## Data and deployment boundary

The proofreading widget is enabled only in development and staging by default.
Adding production to `enabled_environments` is unsupported: key marking changes
rendered application text and the suggestion endpoint is intended for trusted
review environments.

A suggestion can store its translation key, locale, current and proposed text,
comment, page URL, status, timestamps, and optional host-provided author id and
label. Host applications own that data, its backups, retention period, access
controls, and deletion. Delete a suggestion with ordinary Active Record when a
reviewer or application policy requires erasure:

```ruby
I18nProofreading::Suggestion.find(id).destroy!
```

The mounted dashboard is independently protected by `authorize_admin`. Outside
development it fails closed until the host explicitly grants access.
