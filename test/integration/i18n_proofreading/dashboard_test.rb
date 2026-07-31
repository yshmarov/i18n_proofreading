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
      assert_includes response.body, 'name="csp-nonce"'
      assert_includes response.body, 'href="/i18n_proofreading/dashboard.css?v='
      assert_not_includes response.body, '<style>'
      assert_includes response.body, '<title>I18nProofreading</title>'
      assert_includes response.body, '<h1>I18nProofreading</h1>'
      assert_includes response.body, 'Pending wording'
      assert_includes response.body, 'suggestion_id='
      assert_not_includes response.body, 'Applied wording'
    end

    test 'dashboard can render inside a host admin layout' do
      admin!
      I18nProofreading.config.admin_layout = 'host_admin'
      create_suggestion(proposed_value: 'Host layout wording')

      get '/i18n_proofreading/'

      assert_response :ok
      assert_includes response.body, 'data-host-admin-layout="i18n-proofreading"'
      assert_includes response.body, 'Host layout wording'
    end

    test 'serves the dashboard stylesheet as a same-origin static asset' do
      get '/i18n_proofreading/dashboard.css'

      assert_response :ok
      assert_equal 'text/css', response.media_type
      assert_includes response.body, '.tabs'
      assert_includes response.body, '.ip-show { min-height: 100vh; overflow: auto; }'
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

    test 'index can render a selected suggestion beside the list' do
      admin!
      suggestion = create_suggestion(old_value: 'Hello', proposed_value: 'Hi there',
                                     comment: 'friendlier', author_label: 'translator@example.test')

      get '/i18n_proofreading/', params: { suggestion_id: suggestion.id }

      assert_response :ok
      assert_includes response.body, 'review-shell has-selected'
      assert_includes response.body, 'suggestion-row active'
      assert_includes response.body, 'Hi there'
      assert_includes response.body, 'translator@example.test'
      assert_operator response.body.rindex('translator@example.test'), :<, response.body.rindex('Hi there')
      assert_operator response.body.rindex('Hi there'), :<, response.body.rindex('friendlier')
    end

    test 'shows one suggestion independently' do
      admin!
      suggestion = create_suggestion(old_value: 'Hello', proposed_value: 'Hi there',
                                     comment: 'friendlier')

      get "/i18n_proofreading/suggestions/#{suggestion.id}"

      assert_response :ok
      assert_includes response.body, 'class="ip-show"'
      assert_includes response.body, 'sample.greeting'
      assert_includes response.body, 'Hi there'
      assert_includes response.body, 'friendlier'
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
