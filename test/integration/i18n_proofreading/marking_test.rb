# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  # What suggest mode does to the strings a host view renders. A marker must
  # never change what the page renders apart from the marker itself: hosts gate
  # markup on `t(...).presence` (Bullet Train resolves every form field's help
  # and placeholder that way), so a marked blank string would render elements
  # that do not exist outside suggest mode.
  class MarkingTest < ActionDispatch::IntegrationTest
    SUGGESTING = { 'HTTP_COOKIE' => 'i18n_proofreading=1' }.freeze

    test 'still marks a translated string' do
      get '/sample', params: { fields: 1 }, headers: SUGGESTING

      assert_includes response.body, "Hello #{Marking::LEFT}sample.greeting#{Marking::RIGHT}"
    end

    test 'leaves a blank default unmarked, so a presence check still sees nothing' do
      get '/sample', params: { fields: 1 }, headers: SUGGESTING

      assert_not_includes response.body, 'id="help"'
      assert_includes response.body, 'id="name" placeholder=""'
    end

    test 'leaves an empty translation unmarked' do
      get '/sample', params: { fields: 1 }, headers: SUGGESTING

      assert_not_includes response.body, 'id="note"'
      assert_not_includes response.body, "#{Marking::LEFT}sample.empty_note"
    end

    # Rails' `t` helper resolves a String default for a missing key with
    # `I18n.translate(nil, default: ...)`. There is no key to attribute a
    # suggestion to, and an empty marker would never be stripped.
    test 'leaves a keyless default fallback unmarked' do
      get '/sample', params: { fields: 1 }, headers: SUGGESTING

      assert_includes response.body, '<p id="fallback">Fallback title</p>'
      assert_not_includes response.body, "#{Marking::LEFT}#{Marking::RIGHT}"
    end

    test 'marks a key looked up directly through I18n, but never a blank result' do
      Marking.enabled = true

      assert_equal "Hello #{Marking::LEFT}sample.greeting#{Marking::RIGHT}", I18n.t('sample.greeting')
      assert_equal '', I18n.t('sample.empty_note')
      assert_equal '', I18n.t('sample.missing', default: '')
    ensure
      Marking.enabled = false
    end
  end
end
