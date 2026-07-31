# frozen_string_literal: true

module I18nProofreading
  class SuggestionsController < ApplicationController
    PER_PAGE = 50

    # Public widget API is available-gated; the read-only dashboard is admin-gated.
    before_action :require_available, only: %i[context create]
    before_action :require_admin, only: %i[index show]
    before_action :set_suggestion, only: :show

    layout :i18n_proofreading_admin_layout, only: %i[index show]

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

    # --- triage dashboard (admin) --------------------------------------------

    def index
      @status = Suggestion::STATUSES.include?(params[:status]) ? params[:status] : 'pending'
      @locale = params[:locale].presence
      @counts = Suggestion.group(:status).count
      @locales = Suggestion.distinct.pluck(:locale).compact.sort

      scope = Suggestion.where(status: @status)
      scope = scope.where(locale: @locale) if @locale
      @page = [params[:page].to_i, 1].max
      rows = scope.newest_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = rows.size > PER_PAGE
      @suggestions = rows.first(PER_PAGE)

      @selected_suggestion = Suggestion.find_by(id: params[:suggestion_id]) if params[:suggestion_id].present?
    end

    def show; end

    # --- widget API (public) -------------------------------------------------

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

    def set_suggestion
      @suggestion = Suggestion.find(params[:id])
    end

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
