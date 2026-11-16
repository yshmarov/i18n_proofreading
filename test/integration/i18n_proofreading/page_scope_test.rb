# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  class PageScopeTest < ActionDispatch::IntegrationTest
    test 'a controller excludes both markers and automatic injection without changing caching' do
      get '/sample?proofreading_page=off&public_cache=1', headers: suggest_cookie

      assert_plain_page
      assert_equal ['max-age=300', 'public'], response.headers['Cache-Control'].split(', ').sort
      assert_not Marking.enabled?

      get '/sample', headers: suggest_cookie
      assert_review_page
    end

    test 'controller scoped mode requires opt in and respects the suggest cookie' do
      I18nProofreading.config.controller_scoped = true
      get '/sample', headers: suggest_cookie
      assert_plain_page

      get '/sample?proofreading_page=on', headers: suggest_cookie
      assert_review_page
      assert_not Marking.enabled?

      get '/sample?proofreading_page=on'
      assert_includes response.body, 'data-i18n-proofreading-widget'
      assert_not_includes response.body, Marking::LEFT
    end

    test 'controller opt in cannot bypass user or environment gates' do
      I18nProofreading.config.enabled = ->(_request) { false }
      get '/sample?proofreading_page=on', headers: suggest_cookie
      assert_plain_page

      I18nProofreading.config.enabled = ->(_request) { true }
      I18nProofreading.config.enabled_environments = []
      get '/sample?proofreading_page=on', headers: suggest_cookie
      assert_plain_page
    end

    test 'page selectors are callbacks rather than routable controller actions' do
      assert_not_includes SampleController.action_methods, 'enable_i18n_proofreading'
      assert_not_includes SampleController.action_methods, 'disable_i18n_proofreading'
    end

    test 'manual tags honor the same page scope' do
      I18nProofreading.config.auto_inject = false
      I18nProofreading.config.controller_scoped = true
      get '/sample?manual_tag=1', headers: suggest_cookie
      assert_plain_page

      get '/sample?manual_tag=1&proofreading_page=on', headers: suggest_cookie
      assert_review_page

      get '/sample?manual_tag=1&proofreading_page=off', headers: suggest_cookie
      assert_plain_page
    end

    test 'page scope does not disable toggle redirects or suggestion context' do
      I18nProofreading.config.controller_scoped = true
      get '/sample?i18n_proofreading=true'
      assert_response :see_other
      assert_equal '1', response.cookies['i18n_proofreading']

      get '/i18n_proofreading/suggestions/context', params: { locale: 'en', key: 'sample.greeting' }
      assert_response :ok
    end

    private

    def suggest_cookie
      { 'HTTP_COOKIE' => 'i18n_proofreading=1' }
    end

    def assert_plain_page
      assert_response :ok
      assert_not_includes response.body, Marking::LEFT
      assert_not_includes response.body, 'data-i18n-proofreading-widget'
      assert_not_includes response.body, 'data-i18n-proofreading-config'
    end

    def assert_review_page
      assert_response :ok
      assert_includes response.body, "#{Marking::LEFT}sample.greeting#{Marking::RIGHT}"
      assert_includes response.body, 'data-i18n-proofreading-widget'
    end
  end
end
