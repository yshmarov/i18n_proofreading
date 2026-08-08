# frozen_string_literal: true

require 'test_helper'

class SeedsTest < ActiveSupport::TestCase
  test 'loads idempotent demo suggestions across statuses' do
    first = I18nProofreading::Seeds.load!
    second = I18nProofreading::Seeds.load!

    assert_equal 3, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 3, I18nProofreading::Suggestion.where("author_id LIKE 'i18n-proofreading-demo:%'").count
    assert_equal I18nProofreading::Suggestion::STATUSES.sort, first.map(&:status).sort
    assert_includes first.map(&:locale), 'fr'
    assert_includes first.find(&:status_pending?).comment, 'pending suggestions are the review inbox'
    assert_includes first.find(&:status_applied?).comment, 'The gem never edits YAML for you'
    assert_includes first.find(&:status_rejected?).comment, 'Rejected on purpose'
  end
end
