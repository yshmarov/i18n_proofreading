# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :i18n_proofreading_suggestions, force: true do |t|
    t.string :translation_key, null: false
    t.string :locale, null: false
    t.text :old_value
    t.text :proposed_value, null: false
    t.text :comment
    t.string :page_url
    t.string :status, null: false, default: 'pending'
    t.string :author_id
    t.string :author_label
    t.timestamps
  end
end

module ActiveSupport
  class TestCase
    # Start every test from a fresh config (enabled in the test env), so a gating
    # stub in one test can never leak into another; and clear the rate limiter's
    # per-IP cache so one test's flood can't throttle the next.
    setup do
      fresh = I18nProofreading::Configuration.new
      fresh.enabled_environments = %w[test]
      I18nProofreading.instance_variable_set(:@config, fresh)
      Rails.cache.clear
    end
  end
end
