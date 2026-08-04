# frozen_string_literal: true

I18nProofreading.configure do |config|
  # Environments the tool is active in. It is never active anywhere else.
  config.enabled_environments = %w[development staging]

  # Per-request gate on top of the environment check. Return false to hide the
  # tool. Receives the Rack::Request — plug in an admin check, a feature flag, an
  # IP allowlist, etc.
  #
  # config.enabled = ->(request) { true }

  # Who may open the triage dashboard (mounted at your `mount_path`) to review,
  # apply, and delete suggestions. Independent of the checks above — the widget
  # is dev/staging-only, but you may want to triage from production. Defaults to
  # development only; wire it to your own admin check to open it elsewhere.
  #
  # config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
  #
  # Render the dashboard inside your app's admin layout. Default: the gem's
  # standalone dashboard layout.
  #
  # Two ways to put the dashboard inside an admin you already have.
  #
  # The whole stack — your layout, helpers, authentication and any request
  # context your before_actions set up. Only the dashboard inherits it; the
  # widget's endpoints stay public, so this cannot gate a proofreader.
  # config.base_controller_class = "Admin::BaseController"
  #
  # Or the layout alone:
  # config.admin_layout = "admin/application"

  # Attribute a suggestion to a user (optional). Return an object responding to
  # #id (ideally #email too), or nil. Receives the Rack::Request. You resolve the
  # user however your app does — session, Warden, a token, etc.
  #
  # Devise / Warden:
  # config.current_user = ->(request) { request.env["warden"]&.user }
  #
  # Rails 8 built-in auth (bin/rails generate authentication):
  # config.current_user = lambda do |request|
  #   token = request.cookies["session_token"]
  #   Session.find_signed(token)&.user if token
  # end

  # How to label the author in the "already suggested" list.
  #
  # config.author_label = ->(user) { user.try(:email) }

  # The widget is injected into HTML responses automatically. Set this to false to
  # place it yourself with `<%= i18n_proofreading_tag %>` at the end of your layout.
  #
  # config.auto_inject = true

  # Show the floating "Suggest edits" pill. Set false to hide it and toggle
  # suggest mode from your own link instead, e.g.
  # `<%= link_to "Proofread", "?i18n_proofreading=true" %>`. "?i18n_proofreading=false"
  # exits; the choice is remembered in a cookie.
  #
  # config.show_pill = true
  # config.toggle_param = "i18n_proofreading"

  # Default mount path used by `mount_i18n_proofreading`.
  # Override only if you mount the engine manually.
  #
  # config.mount_path = "/i18n_proofreading"

  # Called with each saved suggestion — notify Slack, send an email, open a
  # ticket. Runs inline after save, so keep it fast or hand off to a job.
  #
  # config.on_submit = ->(suggestion) { SuggestionMailer.with(suggestion:).created.deliver_later }

  # Per-IP throttle on the submission endpoint, passed to Rails' built-in rate
  # limiter (Rails 7.2+; ignored on 7.1). Set nil to disable.
  #
  # config.rate_limit = { to: 30, within: 60 }
end
