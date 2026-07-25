# frozen_string_literal: true

module I18nProofreading
  # Lets a host place the widget explicitly (`<%= i18n_proofreading_tag %>` at the end
  # of a layout) instead of relying on auto-injection. Renders nothing unless the
  # tool is available for the current request.
  module TagHelper
    def i18n_proofreading_tag
      return ''.html_safe unless I18nProofreading.available?(request)

      Widget.snippet(
        endpoint: I18nProofreading.config.suggestions_endpoint,
        locale: I18n.locale,
        active: I18nProofreading::Marking.enabled?,
        nonce: (content_security_policy_nonce if respond_to?(:content_security_policy_nonce))
      ).html_safe
    end
  end
end
