# frozen_string_literal: true

require 'test_helper'

module I18nProofreading
  # The widget code is served as a same-origin script (GET {mount}/widget.js)
  # rather than inlined, so it stays runnable under a `'self'`/nonce-based CSP
  # across Turbo body swaps. These tests pin down the serving semantics: plain
  # text/javascript, an ETag for revalidation, and immutable long-lived caching
  # only for the canonical fingerprinted URL.
  class WidgetServingTest < ActionDispatch::IntegrationTest
    test 'serves the widget code as same-origin JavaScript with an ETag' do
      get '/i18n_proofreading/widget.js'

      assert_response :ok
      assert_equal 'text/javascript', response.media_type
      assert_includes response.body, 'i18n_proofreading widget'
      assert_predicate response.headers['ETag'], :present?
    end

    test 'caches the fingerprinted URL long-term (content-addressed, so immutable)' do
      get "/i18n_proofreading/widget.js?v=#{Widget.fingerprint}"

      assert_response :ok
      assert_includes response.headers['Cache-Control'], 'public'
      assert_includes response.headers['Cache-Control'], "max-age=#{1.year.to_i}"
    end

    test 'only ETag-revalidates a missing or stale fingerprint' do
      get '/i18n_proofreading/widget.js?v=stale'

      assert_response :ok
      assert_not_includes response.headers['Cache-Control'].to_s, 'public'
    end

    test 'answers 304 Not Modified to a matching ETag' do
      get '/i18n_proofreading/widget.js'
      etag = response.headers['ETag']

      get '/i18n_proofreading/widget.js', headers: { 'HTTP_IF_NONE_MATCH' => etag }

      assert_response :not_modified
      assert_empty response.body
    end

    test 'serves even where the widget itself is unavailable (static code, no data)' do
      I18nProofreading.config.enabled = ->(_request) { false }

      get '/i18n_proofreading/widget.js'

      assert_response :ok
    end
  end
end
