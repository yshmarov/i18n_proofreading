# frozen_string_literal: true

module I18nProofreading
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    private

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
  end
end
