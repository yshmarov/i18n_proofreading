# frozen_string_literal: true

require 'test_helper'

class I18nProofreadingTest < ActiveSupport::TestCase
  def request
    @request ||= Rack::Request.new(Rack::MockRequest.env_for('/'))
  end

  test 'available? is true in an enabled environment when the gate passes' do
    I18nProofreading.config.enabled = ->(_request) { true }

    assert I18nProofreading.available?(request)
  end

  test 'available? is false when the per-request gate rejects it' do
    I18nProofreading.config.enabled = ->(_request) { false }

    assert_not I18nProofreading.available?(request)
  end

  test 'available? is false outside the enabled environments' do
    I18nProofreading.config.enabled_environments = %w[staging]

    assert_not I18nProofreading.available?(request)
  end
end
