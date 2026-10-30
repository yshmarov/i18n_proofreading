# frozen_string_literal: true

require 'application_system_test_case'

module I18nProofreading
  class TurboTest < ApplicationSystemTestCase
    setup do
      I18nProofreading.config.enabled = ->(request) { request.params['unavailable'] != '1' }
    end

    test 'real Turbo visits disable the tool and history restores a working widget without reloading' do
      visit '/sample?turbo=1&i18n_proofreading=true'
      find("[data-i18n-key='sample.greeting']").click
      assert_selector '.i18np-panel'
      track_turbo

      page.execute_script("Turbo.visit('/sample?turbo=1&unavailable=1')")

      assert_selector 'html[data-proofreading-loads="1"]'
      assert_no_selector '.i18np-pill'
      assert_no_selector '.i18np-panel'
      refute page.evaluate_script("document.documentElement.classList.contains('i18np-active')")
      assert_equal '', page.evaluate_script('document.documentElement.style.overflow')
      assert_equal true, page.evaluate_script('window.proofreadingSoftVisit')
      find_by_id('onward').click
      assert_current_path '/sample?turbo=1&unavailable=1&page=next'
      assert_selector 'html[data-proofreading-loads="2"]'

      # Return across both unavailable pages to the cached proofreading page.
      page.execute_script('history.go(-2)')
      assert_current_path '/sample?turbo=1'
      assert_selector '.i18np-pill', count: 1
      find("[data-i18n-key='sample.greeting']").click
      assert_selector '.i18np-panel'
      assert_equal true, page.evaluate_script('window.proofreadingSoftVisit')
    end

    test 'a real Turbo validation response rebuilds the pill without turbo load' do
      visit '/sample?turbo=1'
      assert_selector '.i18np-pill'
      track_turbo

      click_button 'Validate'

      assert_selector '#validation-error'
      assert_selector '.i18np-pill', count: 1
      assert_equal ['replace'], page.evaluate_script('window.proofreadingRenders')
      assert_equal 0, page.evaluate_script('window.proofreadingLoads')
      assert_equal true, page.evaluate_script('window.proofreadingSoftVisit')
    end

    test 'a real Turbo morph refresh keeps one functional pill' do
      visit '/sample?turbo=1&morph=1'
      assert_selector '.i18np-pill'
      track_turbo
      page.execute_script(<<~JS)
        document.body.dataset.beforeMorph = 'true';
        Turbo.visit(window.location.href, { action: 'replace' });
      JS

      assert_no_selector 'body[data-before-morph]'
      assert_selector '.i18np-pill', count: 1
      assert_includes page.evaluate_script('window.proofreadingRenders'), 'morph'
      assert_equal true, page.evaluate_script('window.proofreadingSoftVisit')
      find('.i18np-pill').click
      assert_selector "[data-i18n-key='sample.greeting']"
    end

    private

    def track_turbo
      page.execute_script(<<~JS)
        window.proofreadingSoftVisit = true;
        window.proofreadingRenders = [];
        window.proofreadingLoads = 0;
        document.addEventListener('turbo:render', function (event) {
          window.proofreadingRenders.push(event.detail.renderMethod);
        });
        document.addEventListener('turbo:load', function () {
          window.proofreadingLoads += 1;
          document.documentElement.dataset.proofreadingLoads = window.proofreadingLoads;
        });
      JS
    end
  end
end
