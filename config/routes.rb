# frozen_string_literal: true

I18nProofreading::Engine.routes.draw do
  # The widget code, served same-origin so it runs under a `'self'`/nonce-based
  # CSP even across Turbo body swaps (see WidgetsController).
  get 'widget.js', to: 'widgets#show', as: :widget
  get 'dashboard.css', to: 'widgets#dashboard_stylesheet', as: :dashboard_stylesheet

  # index is the read-only admin dashboard; create + the `context` collection
  # route are the widget's public API (see SuggestionsController). There is
  # deliberately no update/destroy — the tool never mutates suggestions from the
  # UI, since it can't write to the host's locale files.
  # The widget's two endpoints go to SubmissionsController: they are public and
  # the dashboard is staff-only, and only the staff half inherits
  # config.base_controller_class. Sharing one controller would put a host's admin
  # authentication in front of every proofreader. URLs are unchanged.
  get 'suggestions/context', to: 'submissions#context', as: :context_suggestions
  post 'suggestions', to: 'submissions#create', as: :submissions
  resources :suggestions, only: %i[index show]

  root to: 'suggestions#index'
end
