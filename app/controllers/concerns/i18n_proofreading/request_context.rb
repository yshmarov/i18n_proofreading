# frozen_string_literal: true

require 'uri'

module I18nProofreading
  # Who is asking, and the gates that answer it.
  #
  # A concern rather than inherited behaviour because the engine has two
  # controller roots: the public endpoints hang off ActionController::Base, and
  # the dashboard hangs off whatever the host set as `base_controller_class`.
  module RequestContext
    extend ActiveSupport::Concern

    private

    def i18n_proofreading_admin_layout
      I18nProofreading.config.admin_layout
    end

    # Gate for the widget's public API (submit a suggestion, read prior context).
    # The client can set the cookie, but it can never reach the endpoints unless
    # the app itself says the tool is available for this request.
    def require_available
      head :forbidden unless I18nProofreading.available?(request)
    end

    # Gate for the triage dashboard. Independent of #require_available (see
    # I18nProofreading.admin?). Renders a plain 403 with a hint rather than a bare
    # head, since a human is usually looking at it.
    def require_admin
      return if I18nProofreading.admin?(request)

      render plain: 'Forbidden. Set I18nProofreading.config.authorize_admin to grant access.',
             status: :forbidden
    end

    def current_author
      return @current_author if defined?(@current_author)

      @current_author = I18nProofreading.config.current_user.call(request)
    end

    # Browser URLs can carry password-reset tokens, signed ids, and campaign
    # details in their query or fragment. Store only a bounded HTTP(S) location
    # without credentials before it reaches the suggestion table.
    def clean_page_url(value)
      raw = value.to_s
      return if raw.blank? || raw.length > 2_048

      uri = URI.parse(raw)
      return unless %w[http https].include?(uri.scheme&.downcase)
      return if uri.host.blank? || uri.userinfo.present?

      uri.query = nil
      uri.fragment = nil
      uri.to_s.first(255)
    rescue URI::InvalidURIError
      nil
    end
  end
end
