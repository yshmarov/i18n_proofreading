# frozen_string_literal: true

module I18nProofreading
  # Call from a before_action, before any translations are rendered. Page scope
  # never grants access: the middleware's environment/user gate remains required.
  module ControllerMethods
    private

    def enable_i18n_proofreading
      request.env[PageScope::ENABLED] = true
      Marking.enabled = request.env[PageScope::MARKING] == true
    end

    def disable_i18n_proofreading
      request.env[PageScope::ENABLED] = false
      Marking.enabled = false
    end
  end

  module PageScope
    ENABLED = 'i18n_proofreading.page_enabled'
    MARKING = 'i18n_proofreading.marking_allowed'

    def self.enabled?(request)
      request.env.fetch(ENABLED) { !I18nProofreading.config.controller_scoped }
    end
  end
end
