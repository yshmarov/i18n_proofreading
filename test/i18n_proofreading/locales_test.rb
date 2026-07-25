# frozen_string_literal: true

require 'test_helper'
require 'yaml'

module I18nProofreading
  # Guards the bundled translations. The widget/UI keys must be present in every
  # shipped locale, so no language is ever missing a label after an edit. The
  # dashboard keys (`dashboard`, `statuses`) are an admin-facing surface shipped
  # in English only — rendered through I18n with English fallbacks — so they live
  # in en.yml alone and are excluded from the per-locale parity check.
  class LocalesTest < ActiveSupport::TestCase
    LOCALES_DIR = File.expand_path('../../config/locales', __dir__)
    ADMIN_ONLY_KEYS = %w[dashboard statuses].freeze

    def self.keys_for(file)
      data = YAML.load_file(file)
      locale = data.keys.first
      data.fetch(locale).fetch('i18n_proofreading').keys.map(&:to_s)
    end

    def self.widget_keys(file)
      (keys_for(file) - ADMIN_ONLY_KEYS).sort
    end

    FILES = Dir["#{LOCALES_DIR}/i18n_proofreading.*.yml"]
    EN_FILE = File.join(LOCALES_DIR, 'i18n_proofreading.en.yml')
    EXPECTED_WIDGET_KEYS = widget_keys(EN_FILE)

    test 'ships 25+ languages besides English' do
      assert_operator FILES.size, :>=, 26
    end

    test 'includes the host-facing toggle labels in English' do
      assert_includes EXPECTED_WIDGET_KEYS, 'start'
      assert_includes EXPECTED_WIDGET_KEYS, 'stop'
    end

    test 'ships the dashboard strings in English' do
      en = YAML.load_file(EN_FILE)['en']['i18n_proofreading']
      assert_equal %w[applied pending rejected], en['statuses'].keys.sort
      %w[title subtitle current suggested empty].each { |k| assert_includes en['dashboard'].keys, k }
    end

    FILES.each do |file|
      name = File.basename(file)
      define_method("test_#{name}_carries_the_same_widget_keys_as_English") do
        assert_equal EXPECTED_WIDGET_KEYS, self.class.widget_keys(file)
      end
    end
  end
end
