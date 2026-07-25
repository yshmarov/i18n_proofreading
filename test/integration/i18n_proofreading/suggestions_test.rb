# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  class SuggestionsTest < ActionDispatch::IntegrationTest
    def valid_params
      {
        suggestion: {
          translation_key: 'sample.greeting',
          locale: 'en',
          old_value: 'Hello',
          proposed_value: 'Hi there',
          comment: 'friendlier',
          page_url: 'http://example.test/sample'
        }
      }
    end

    # --- POST /i18n_proofreading/suggestions ---------------------------------

    test 'stores the suggestion' do
      assert_difference -> { Suggestion.count }, 1 do
        post '/i18n_proofreading/suggestions', params: valid_params
      end

      assert_response :created
      assert_equal 'Hi there', Suggestion.last.proposed_value
    end

    test 'rejects an invalid suggestion' do
      post '/i18n_proofreading/suggestions',
           params: { suggestion: { translation_key: '', locale: 'en', proposed_value: '' } }

      assert_response :unprocessable_entity
    end

    test 'attributes the suggestion via the configured resolver' do
      author = Struct.new(:id, :email).new(42, 'translator@example.test')
      I18nProofreading.config.current_user = ->(_request) { author }

      post '/i18n_proofreading/suggestions', params: valid_params

      suggestion = Suggestion.last
      assert_equal '42', suggestion.author_id
      assert_equal 'translator@example.test', suggestion.author_label
    end

    test 'is forbidden when the tool is not available for the request' do
      I18nProofreading.config.enabled = ->(_request) { false }

      post '/i18n_proofreading/suggestions', params: valid_params

      assert_response :forbidden
    end

    test 'runs the on_submit hook with the saved suggestion' do
      submitted = nil
      I18nProofreading.config.on_submit = ->(suggestion) { submitted = suggestion }

      post '/i18n_proofreading/suggestions', params: valid_params

      assert_kind_of Suggestion, submitted
      assert_predicate submitted, :persisted?
      assert_equal 'Hi there', submitted.proposed_value
    end

    test 'does not run the on_submit hook when the suggestion is invalid' do
      ran = false
      I18nProofreading.config.on_submit = ->(_suggestion) { ran = true }

      post '/i18n_proofreading/suggestions',
           params: { suggestion: { translation_key: '', locale: 'en', proposed_value: '' } }

      assert_not ran
    end

    test 'throttles a flood of submissions from one IP with a 429' do
      # Rate limiting rides on Rails' built-in limiter (7.2+); on 7.1 the macro is
      # skipped and there is nothing to assert.
      skip 'rate limiting requires Rails 7.2+' unless SuggestionsController.respond_to?(:rate_limit)

      # The active limit is baked into the controller at load time from the
      # default config; read it from a fresh Configuration rather than hardcoding.
      limit = Configuration.new.rate_limit.fetch(:to)

      limit.times do
        post '/i18n_proofreading/suggestions', params: valid_params
        assert_response :created
      end

      post '/i18n_proofreading/suggestions', params: valid_params
      assert_response :too_many_requests
    end

    # --- GET /i18n_proofreading/suggestions/context --------------------------

    test 'lists pending suggestions for a key and locale' do
      Suggestion.create!(translation_key: 'sample.greeting', locale: 'en', proposed_value: 'Hi')
      Suggestion.create!(translation_key: 'other.key', locale: 'en', proposed_value: 'Nope')

      get '/i18n_proofreading/suggestions/context', params: { key: 'sample.greeting', locale: 'en' }

      assert_response :ok
      body = response.parsed_body
      assert_equal 1, body.size
      assert_equal 'Hi', body.first['proposed_value']
    end

    test 'shows only pending suggestions as context, not applied or rejected ones' do
      Suggestion.create!(translation_key: 'sample.greeting', locale: 'en', proposed_value: 'Pending one')
      Suggestion.create!(translation_key: 'sample.greeting', locale: 'en', proposed_value: 'Applied one',
                         status: 'applied')

      get '/i18n_proofreading/suggestions/context', params: { key: 'sample.greeting', locale: 'en' }

      values = response.parsed_body.map { |item| item['proposed_value'] }
      assert_equal ['Pending one'], values
    end

    test 'context is forbidden when the tool is not available for the request' do
      I18nProofreading.config.enabled = ->(_request) { false }

      get '/i18n_proofreading/suggestions/context', params: { key: 'sample.greeting', locale: 'en' }

      assert_response :forbidden
    end
  end
end
