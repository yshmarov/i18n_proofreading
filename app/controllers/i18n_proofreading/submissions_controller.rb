# frozen_string_literal: true

module I18nProofreading
  # The widget's public API: the context lookup it reads and the suggestion it
  # posts.
  #
  # Public, so it stays on ApplicationController and never inherits a host's
  # admin base controller — a proofreader must not be asked for a staff session.
  # The triage actions live in SuggestionsController, which does inherit it.
  class SubmissionsController < ApplicationController
    before_action :require_available

    # Throttle the public submission endpoint per IP so one user or bot can't
    # flood the table. Uses the rate limiter built into Rails 7.2+ (backed by
    # Rails.cache); a no-op on Rails 7.1. Tune or disable via config.rate_limit —
    # read once at boot, after the host's initializer.
    if respond_to?(:rate_limit) && I18nProofreading.config.rate_limit
      rate_limit(**I18nProofreading.config.rate_limit,
                 only: :create,
                 with: lambda {
                   render json: { errors: ['Too many suggestions. Please slow down and try again.'] },
                          status: :too_many_requests
                 })
    end

    # Pending suggestions for one key/locale, shown as read-only context when the
    # proofreader reopens the popover for a string someone already flagged.
    def context
      suggestions = Suggestion
                    .where(translation_key: params[:key], locale: params[:locale])
                    .status_pending
                    .newest_first
                    .limit(20)

      render json: suggestions.map { |suggestion| suggestion_json(suggestion) }
    end

    def create
      suggestion = Suggestion.new(suggestion_params)
      attribute_author(suggestion)

      if suggestion.save
        I18nProofreading.config.on_submit.call(suggestion)
        head :created
      else
        render json: { errors: suggestion.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def attribute_author(suggestion)
      author = current_author
      return unless author

      suggestion.author_id = author.id.to_s if author.respond_to?(:id)
      suggestion.author_label = I18nProofreading.config.author_label.call(author)
    end

    def suggestion_json(suggestion)
      {
        proposed_value: suggestion.proposed_value,
        author_label: suggestion.author_label,
        created_at: suggestion.created_at.iso8601
      }
    end

    def suggestion_params
      params
        .require(:suggestion)
        .permit(:translation_key, :locale, :old_value, :proposed_value, :comment, :page_url)
    end
  end
end
