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

    # The plain sample has no Turbo, so these tests do what Turbo Drive does on a
    # visit: replace <body> (keeping <html> and <head>), then fire the event.
    # A body with no config block is a page the tool is not available on: the
    # middleware injected nothing (signed out, `enabled` false, a layout without
    # the tag). A cached snapshot can still carry the last page's pill.
    UNAVAILABLE_BODY = <<~HTML
      <h1>Elsewhere</h1>
      <a id="onward" href="#landed">Onward</a>
      <button type="button" class="i18np-pill">✎ Suggest edits</button>
    HTML

    test 'a Turbo visit to a page without the tool removes the pill' do
      visit '/sample'
      assert_selector '.i18np-pill'

      turbo_swap_body(UNAVAILABLE_BODY, 'turbo:load')

      assert_text 'Elsewhere'
      assert_no_selector '.i18np-pill'
    end

    test 'a Turbo visit out of suggest mode to a page without the tool unfreezes navigation' do
      visit '/sample'
      find('.i18np-pill').click
      assert_selector "[data-i18n-key='sample.greeting']" # in suggest mode

      turbo_swap_body(UNAVAILABLE_BODY, 'turbo:load')

      refute page.evaluate_script("document.documentElement.classList.contains('i18np-active')")
      find_by_id('onward').click
      assert_equal '#landed', page.evaluate_script('window.location.hash')
      find('body').send_keys(:escape) # no reload into a stale suggest mode
      assert_equal '#landed', page.evaluate_script('window.location.hash')
    end

    test 'a Turbo visit back to a page with the tool brings the pill back' do
      visit '/sample'
      available_body = server_body

      turbo_swap_body(UNAVAILABLE_BODY, 'turbo:load')
      assert_no_selector '.i18np-pill'

      turbo_swap_body(available_body, 'turbo:load')
      assert_selector '.i18np-pill'
    end

    # A form that fails validation (422) is rendered by Turbo with turbo:render
    # and no turbo:load, so the swapped-in page still needs its pill.
    test 'a Turbo render without a visit keeps the pill' do
      visit '/sample'
      available_body = server_body

      turbo_swap_body(available_body, 'turbo:render')

      assert_selector '.i18np-pill', count: 1
    end

    test 'malformed configuration switches off suggest mode and releases an open dialog' do
      visit '/sample?i18n_proofreading=true'
      find("[data-i18n-key='sample.greeting']").click
      assert_selector '.i18np-panel'

      turbo_swap_body("#{UNAVAILABLE_BODY}<script data-i18n-proofreading-config>{broken</script>", 'turbo:render')

      assert_no_selector '.i18np-pill'
      assert_no_selector '.i18np-panel'
      assert_equal '', page.evaluate_script('document.documentElement.style.overflow')
      find_by_id('onward').click
      assert_equal '#landed', page.evaluate_script('window.location.hash')
    end

    test 'a render that preserves the dialog closes it when the tool becomes unavailable' do
      visit '/sample?i18n_proofreading=true'
      find("[data-i18n-key='sample.greeting']").click
      assert_selector '.i18np-panel'

      page.execute_script(<<~JS)
        document.querySelector('script[data-i18n-proofreading-config]').remove();
        document.dispatchEvent(new Event('turbo:render', { bubbles: true }));
      JS

      assert_no_selector '.i18np-panel'
      assert_no_selector '.i18np-pill'
      assert_equal '', page.evaluate_script('document.documentElement.style.overflow')
    end

    test 'show_pill :auto leaves the pill to pages without a host toggle link' do
      I18nProofreading.config.show_pill = :auto

      visit '/sample'
      assert_selector '.i18np-pill'

      visit '/sample?toggle_link=1'
      assert_selector '#toggle'
      assert_no_selector '.i18np-pill'

      # The host link alone drives suggest mode, in and out.
      find_by_id('toggle').click
      assert_selector "[data-i18n-key='sample.greeting']"
      assert_no_selector '.i18np-pill'
      find_by_id('toggle').click
      assert_no_selector "[data-i18n-key='sample.greeting']"
    end

    test 'strips an empty marker that reaches the page' do
      visit '/sample?stray=1&i18n_proofreading=true'

      assert_selector "[data-i18n-key='sample.greeting']" # in suggest mode
      assert_equal 'Kept', find_by_id('stray').text
      assert_equal '', find_by_id('stray-input')['placeholder']
    end

    test 'render and load respect showPill false even when a cached pill remains' do
      visit '/sample'
      assert_selector '.i18np-pill'

      page.execute_script(<<~JS)
        var element = document.querySelector('script[data-i18n-proofreading-config]');
        var config = JSON.parse(element.textContent);
        config.showPill = false;
        element.textContent = JSON.stringify(config);
        document.dispatchEvent(new Event('turbo:render', { bubbles: true }));
        document.dispatchEvent(new Event('turbo:load', { bubbles: true }));
      JS

      assert_no_selector '.i18np-pill'
    end

    private

    # The page as the server sent it: the pill is built by the widget, so a
    # fresh response never contains one.
    def server_body
      page.evaluate_script(<<~JS)
        (function () {
          var body = document.body.cloneNode(true);
          body.querySelectorAll('.i18np-pill').forEach(function (pill) { pill.remove(); });
          return body.innerHTML;
        })()
      JS
    end

    def turbo_swap_body(html, event)
      page.execute_script(<<~JS, html, event)
        var body = document.createElement('body');
        body.innerHTML = arguments[0];
        document.body.replaceWith(body);
        document.dispatchEvent(new Event(arguments[1], { bubbles: true }));
      JS
    end
  end
end
