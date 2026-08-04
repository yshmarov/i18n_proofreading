# frozen_string_literal: true

require 'i18n_proofreading/version'
require 'i18n_proofreading/configuration'
require 'i18n_proofreading/marking'
require 'i18n_proofreading/widget'
require 'i18n_proofreading/middleware'
require 'i18n_proofreading/seeds'
require 'i18n_proofreading/engine'

# In-context translation proofreading for Rails. Renders each i18n key alongside
# its text in the chosen environments, lets a proofreader click any string and
# suggest a better wording, and stores the suggestions for a developer to apply.
module I18nProofreading
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Is the tool available for this request? True only in an enabled environment
    # and when the host's `enabled` predicate passes. Checked on the server for
    # every marker, endpoint, and injection, so the client can never turn it on.
    def available?(request)
      config.environment_enabled? && !!config.enabled.call(request)
    end

    # May this request browse and triage the dashboard? Independent of
    # `available?` — the dashboard has its own gate so maintainers can review
    # suggestions from production even where the widget itself is off.
    # The class I18nProofreading::DashboardController inherits from. Resolved on
    # every call rather than memoized, so a host that reassigns
    # base_controller_class in a reloadable initializer is not pinned to a stale,
    # unloaded constant.
    def base_controller
      config.base_controller_class.to_s.constantize
    end

    def admin?(request)
      !!config.authorize_admin.call(request)
    end
  end
end
