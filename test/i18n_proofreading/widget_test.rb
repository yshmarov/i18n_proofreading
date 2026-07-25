# frozen_string_literal: true

require 'test_helper'
require 'json'

module I18nProofreading
  class WidgetTest < ActiveSupport::TestCase
    def config_from(snippet)
      JSON.parse(snippet[%r{data-i18n-proofreading-config>(.*?)</script>}m, 1])
    end

    test 'stays out of the host asset pipeline (no app/assets to auto-register)' do
      assert_empty Engine.paths['app/assets'].existent
      assert File.exist?(Widget::SOURCE)
    end

    # --- direction ------------------------------------------------------------

    test 'marks right-to-left locales' do
      %i[ar ur].each do |locale|
        config = config_from(Widget.snippet(endpoint: '/x', locale: locale, active: false))
        assert config['rtl'], "expected #{locale} to be RTL"
      end
    end

    test 'treats a region variant by its language subtag' do
      config = config_from(Widget.snippet(endpoint: '/x', locale: 'ar-EG', active: false))
      assert config['rtl']
    end

    test 'leaves left-to-right locales unmarked' do
      %i[en de ja].each do |locale|
        config = config_from(Widget.snippet(endpoint: '/x', locale: locale, active: false))
        assert_not config['rtl'], "expected #{locale} to be LTR"
      end
    end

    # --- escaping -------------------------------------------------------------

    test 'escapes </ so a config value cannot close the script block early' do
      I18nProofreading.config.pill_label = '</script><script>alert(1)</script>'

      snippet = Widget.snippet(endpoint: '/x', locale: :en, active: false)
      json = snippet[%r{data-i18n-proofreading-config>(.*?)</script>}m, 1]

      # The extracted block stops at the real closing tag, so the payload must not
      # have introduced one of its own — yet the value round-trips intact.
      assert_not_includes json, '</script>'
      assert_equal '</script><script>alert(1)</script>', config_from(snippet)['pillLabel']
    end
  end

  class WidgetLabelsTest < ActiveSupport::TestCase
    # These locales aren't in the dummy app's available_locales; the enforcement
    # is about the app's own locale, not which translations the gem ships. A prior
    # request test runs the Rails reloader, which filters the loaded backend down
    # to the app's available_locales ([:en, :fr]) — so reload the full load_path
    # (all shipped gem locales) to keep these tests order-proof.
    setup do
      @enforce = I18n.enforce_available_locales
      I18n.enforce_available_locales = false
      I18n.reload!
      I18n.backend.load_translations
    end

    teardown do
      I18n.enforce_available_locales = @enforce
    end

    def config_from(snippet)
      JSON.parse(snippet[%r{data-i18n-proofreading-config>(.*?)</script>}m, 1])
    end

    test 'ships translations for the bundled locales' do
      # A spot check across scripts: Latin, Cyrillic, CJK, Arabic, Devanagari.
      {
        'de' => 'Vorschlag senden',
        'ru' => 'Отправить предложение',
        'ja' => '提案を送信',
        'ar' => 'إرسال الاقتراح',
        'hi' => 'सुझाव भेजें'
      }.each do |locale, expected|
        value = I18n.t(:save, scope: :i18n_proofreading, locale: locale)
        assert_equal expected, value, "#{locale}.i18n_proofreading.save"
      end
    end

    test 'falls back to English for a locale with no shipped translation' do
      assert_equal 'Send suggestion',
                   I18n.t(:save, scope: :i18n_proofreading, locale: :xx, default: 'Send suggestion')
    end

    test 'resolves labels under the requested locale, not the ambient I18n.locale' do
      config = I18n.with_locale(:en) do
        config_from(Widget.snippet(endpoint: '/x', locale: :fr, active: false))
      end

      assert_equal 'Envoyer la suggestion', config['labels']['save']
    end

    test 'lets the host override a shipped label from its own locale files' do
      # Force the lazy load first; otherwise the next translate reloads from disk
      # and wipes the store_translations override before snippet reads it.
      I18n.t(:save, scope: :i18n_proofreading, locale: :fr)
      I18n.backend.store_translations(:fr, i18n_proofreading: { save: 'Soumettre' })

      config = config_from(Widget.snippet(endpoint: '/x', locale: :fr, active: false))

      assert_equal 'Soumettre', config['labels']['save']
    ensure
      I18n.reload!
    end
  end
end
