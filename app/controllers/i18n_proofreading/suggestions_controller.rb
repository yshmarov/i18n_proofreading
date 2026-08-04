# frozen_string_literal: true

module I18nProofreading
  class SuggestionsController < DashboardController
    PER_PAGE = 50

    # Public widget API is available-gated; the read-only dashboard is admin-gated.
    before_action :set_suggestion, only: :show

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

    private

    def set_suggestion
      @suggestion = Suggestion.find(params[:id])
    end
  end
end
