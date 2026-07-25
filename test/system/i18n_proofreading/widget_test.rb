# frozen_string_literal: true

require 'application_system_test_case'

module I18nProofreading
  # Drives the actual browser widget end to end: the pill, entering suggest mode,
  # the marker-stripping, the popover, and a real POST that stores a suggestion.
  # Nothing else in the suite exercises the widget JavaScript in a browser.
  class WidgetTest < ApplicationSystemTestCase
    test 'a reviewer clicks a string and suggests a fix' do
      visit '/sample'

      # The floating pill is present, suggest mode off (no markers yet).
      assert_selector '.i18np-pill'
      assert_no_selector "[data-i18n-key='sample.greeting']"

      # Turn suggest mode on — the pill sets the cookie and reloads; the widget
      # then strips the ⟦key⟧ markers and tags the element with its i18n key.
      find('.i18np-pill').click
      greeting = find("[data-i18n-key='sample.greeting']")
      assert_equal 'Hello', greeting.text

      # Clicking a tagged string opens the suggestion popover.
      greeting.click
      assert_selector '.i18np-panel'
      assert_selector '.i18np-readonly', text: 'Hello' # current text shown

      # Propose a better wording and send it.
      find('textarea.i18np-input').set('Hi there')
      assert_difference -> { Suggestion.count }, 1 do
        find('.i18np-btn-primary').click
        assert_no_selector '.i18np-panel' # popover closes on success
      end

      suggestion = Suggestion.last
      assert_equal 'sample.greeting', suggestion.translation_key
      assert_equal 'Hi there', suggestion.proposed_value
      assert_equal 'Hello', suggestion.old_value
    end

    test 'Escape exits suggest mode' do
      visit '/sample'
      find('.i18np-pill').click
      assert_selector "[data-i18n-key='sample.greeting']" # in suggest mode

      find('body').send_keys(:escape)
      assert_no_selector "[data-i18n-key='sample.greeting']" # markers gone — back out
    end
  end
end
