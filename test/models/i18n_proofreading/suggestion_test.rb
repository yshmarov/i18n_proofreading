# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  class SuggestionTest < ActiveSupport::TestCase
    test 'requires a key, a proposed value, and a locale' do
      suggestion = Suggestion.new

      assert_not suggestion.valid?
      assert_includes suggestion.errors.attribute_names, :translation_key
      assert_includes suggestion.errors.attribute_names, :proposed_value
      assert_includes suggestion.errors.attribute_names, :locale
    end

    test 'accepts a locale the app knows about' do
      suggestion = Suggestion.new(translation_key: 'sample.greeting', proposed_value: 'Hi', locale: 'fr')

      assert suggestion.valid?
    end

    test 'rejects a locale the app does not offer' do
      suggestion = Suggestion.new(translation_key: 'sample.greeting', proposed_value: 'Hi', locale: 'de')

      assert_not suggestion.valid?
      assert_includes suggestion.errors.attribute_names, :locale
    end

    test 'starts out pending' do
      suggestion = Suggestion.create!(translation_key: 'sample.greeting', proposed_value: 'Hi', locale: 'en')

      assert_equal 'pending', suggestion.status
      assert_predicate suggestion, :status_pending?
      assert_not_predicate suggestion, :status_applied?
    end

    test 'exposes a predicate for each status' do
      suggestion = Suggestion.new(status: 'applied')

      assert_predicate suggestion, :status_applied?
      assert_not_predicate suggestion, :status_pending?
      assert_not_predicate suggestion, :status_rejected?
    end

    test 'refuses to be assigned an unknown status' do
      assert_raises(ArgumentError) { Suggestion.new(status: 'archived') }
    end

    test 'caps the length of the free-text fields' do
      suggestion = Suggestion.new(
        translation_key: 'sample.greeting',
        locale: 'en',
        proposed_value: 'a' * 5_001,
        old_value: 'b' * 5_001,
        comment: 'c' * 2_001,
        page_url: "http://x/#{'d' * 2_001}"
      )

      assert_not suggestion.valid?
      %i[proposed_value old_value comment page_url].each do |attr|
        assert_includes suggestion.errors.attribute_names, attr
      end
    end

    test 'accepts free-text fields at the maximum length' do
      suggestion = Suggestion.new(
        translation_key: 'sample.greeting', locale: 'en', proposed_value: 'a' * 5_000
      )

      assert suggestion.valid?
    end
  end
end
