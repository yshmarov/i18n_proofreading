# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  class DashboardTest < ActionDispatch::IntegrationTest
    def admin!
      I18nProofreading.config.authorize_admin = ->(_request) { true }
    end

    def create_suggestion(**attrs)
      Suggestion.create!(
        { translation_key: 'sample.greeting', locale: 'en', proposed_value: 'Hi' }.merge(attrs)
      )
    end

    test 'index is forbidden unless authorize_admin passes' do
      # Default in the test env is development-only, i.e. false here.
      get '/i18n_proofreading/'

      assert_response :forbidden
    end

    test 'index lists suggestions for the selected status' do
      admin!
      create_suggestion(proposed_value: 'Pending wording')
      create_suggestion(proposed_value: 'Applied wording', status: 'applied')

      get '/i18n_proofreading/', params: { status: 'pending' }

      assert_response :ok
      assert_includes response.body, 'Pending wording'
      assert_not_includes response.body, 'Applied wording'
    end

    test 'index defaults to pending and can switch to applied' do
      admin!
      create_suggestion(proposed_value: 'Applied wording', status: 'applied')

      get '/i18n_proofreading/'
      assert_not_includes response.body, 'Applied wording'

      get '/i18n_proofreading/', params: { status: 'applied' }
      assert_includes response.body, 'Applied wording'
    end

    test 'index filters by locale' do
      admin!
      create_suggestion(locale: 'en', proposed_value: 'English wording')
      create_suggestion(locale: 'fr', proposed_value: 'French wording')

      get '/i18n_proofreading/', params: { status: 'pending', locale: 'fr' }

      assert_includes response.body, 'French wording'
      assert_not_includes response.body, 'English wording'
    end

    test 'renders the locale filter with a label and a submit button (works without JS / under a strict CSP)' do
      admin!
      create_suggestion(locale: 'en')
      create_suggestion(locale: 'fr')

      get '/i18n_proofreading/'

      assert_includes response.body, '<label for="i18np-locale"'
      assert_match(%r{<form class="filters"[^>]*>.*<button[^>]*>Filter</button>.*</form>}m, response.body)
    end

    # The dashboard never writes to the host's locale files, so it deliberately
    # exposes no way to change or delete a suggestion — status is managed out of
    # band (console / a future apply feature).
    test 'does not route PATCH or DELETE for a suggestion' do
      admin!
      suggestion = create_suggestion

      patch "/i18n_proofreading/suggestions/#{suggestion.id}", params: { status: 'applied' }
      assert_response :not_found

      delete "/i18n_proofreading/suggestions/#{suggestion.id}"
      assert_response :not_found

      assert_equal 'pending', suggestion.reload.status
    end
  end
end
