# frozen_string_literal: true

module I18nProofreading
  # Root of the engine's PUBLIC surface: widget.js, the context lookup and the
  # suggestion endpoint. These stay on a plain ActionController::Base
  # deliberately — a proofreader suggesting a translation must not be routed
  # through a host's admin controller, which would demand a staff session.
  #
  # The dashboard's root is DashboardController, and that is where
  # `config.base_controller_class` applies.
  class ApplicationController < ActionController::Base
    include RequestContext

    protect_from_forgery with: :exception
  end
end
