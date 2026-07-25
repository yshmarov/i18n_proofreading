# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  class WidgetInjectionTest < ActionDispatch::IntegrationTest
    test 'injects the widget into HTML responses when the tool is available' do
      get '/sample'

      assert_response :ok
      assert_includes response.body, 'data-i18n-proofreading-config'
      assert_includes response.body, 'data-i18n-proofreading-widget'
    end

    test 'does not emit key markers without the suggest-mode cookie' do
      get '/sample'

      assert_not_includes response.body, "#{Marking::LEFT}sample.greeting"
    end

    test 'emits key markers when the suggest-mode cookie is set' do
      get '/sample', headers: { 'HTTP_COOKIE' => 'i18n_proofreading=1' }

      assert_includes response.body, "#{Marking::LEFT}sample.greeting#{Marking::RIGHT}"
    end

    test 'never marks its own UI strings, even in suggest mode' do
      get '/sample', headers: { 'HTTP_COOKIE' => 'i18n_proofreading=1' }

      config = response.body[%r{data-i18n-proofreading-config>(.*?)</script>}m, 1]
      assert_includes config, '"labels":'
      assert_not_includes config, Marking::LEFT
      assert_not_includes config, 'i18n_proofreading.title'
    end

    test 'injects nothing when the tool is unavailable' do
      I18nProofreading.config.enabled = ->(_request) { false }

      get '/sample'

      assert_not_includes response.body, 'data-i18n-proofreading-widget'
    end

    test 'turns suggest mode on via the toggle parameter, then redirects to the clean URL' do
      get '/sample', params: { i18n_proofreading: 'true' }

      assert_response :see_other
      assert_equal '/sample', response.location
      assert_equal '1', response.cookies['i18n_proofreading']
    end

    test 'turns suggest mode off via the toggle parameter, then redirects to the clean URL' do
      get '/sample', params: { i18n_proofreading: 'false' }, headers: { 'HTTP_COOKIE' => 'i18n_proofreading=1' }

      assert_response :see_other
      assert_equal '/sample', response.location
      assert_predicate response.cookies['i18n_proofreading'], :blank?
    end

    test 'injects localized UI labels into the config' do
      get '/sample'

      assert_includes response.body, '"labels":'
      assert_includes response.body, '"save":"Send suggestion"'
    end

    test 'follows the app locale for the widget labels using the shipped translations' do
      I18n.with_locale(:fr) { get '/sample' }

      assert_includes response.body, '"save":"Envoyer la suggestion"'
      assert_includes response.body, '"cancel":"Annuler"'
    end

    test "follows the page's rendered language even when the ambient locale was reset" do
      # The page renders in French while I18n.locale stays :en — the situation an
      # `around_action { I18n.with_locale(...) }` leaves the middleware in.
      get '/sample', params: { page_lang: 'fr' }

      assert_equal :en, I18n.locale
      assert_includes response.body, '"locale":"fr"'
      assert_includes response.body, '"save":"Envoyer la suggestion"'
    end

    test 'falls back to the ambient locale when the page language is not an available locale' do
      get '/sample', params: { page_lang: 'de' } # de is not in the dummy app's available_locales

      assert_includes response.body, '"locale":"en"'
      assert_includes response.body, '"save":"Send suggestion"'
    end

    test 'omits the pill from the injected config when show_pill is false' do
      I18nProofreading.config.show_pill = false

      get '/sample'

      assert_includes response.body, '"showPill":false'
    end

    test 'stamps the widget script with the CSP nonce, leaving the JSON config (data, not code) unstamped' do
      get '/sample'

      assert_includes response.body, '<script data-i18n-proofreading-widget nonce="testnonce">'
      assert_includes response.body, '<script type="application/json" data-i18n-proofreading-config>'
      assert_no_match(/data-i18n-proofreading-config[^>]*nonce=/, response.body)
    end
  end
end
