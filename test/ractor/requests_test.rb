# frozen_string_literal: true

# A separate process: ractorize! freezes Rails and cannot share a process with
# the ordinary suite, whose tests deliberately replace configuration per test.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'rack/mock'

ENV['RAILS_ENV'] = 'ractor'
ractor_directory = Dir.mktmpdir('i18n_proofreading-ractor-')
ENV['DATABASE_URL'] = "sqlite3:#{ractor_directory}/test.sqlite3"
at_exit { FileUtils.remove_entry(ractor_directory) }

require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'i18n_proofreading'
require 'minitest/autorun'
require 'active_support/ractors'

raise 'Use Rails edge and Ruby 4.0+ for test:ractor' unless Rails::Application.method_defined?(:ractorize!) &&
                                                            defined?(Ractor.shareable_lambda)

ActiveSupport::Ractors.unshareable_proc_action = :raise
FileUtils.mkdir_p("#{ractor_directory}/config/environments")
File.write("#{ractor_directory}/config/environments/ractor.rb", "# Dedicated Ractor host\n")

class RactorHost < Rails::Application
  config.load_defaults 7.1
  config.secret_key_base = 'ractor-test-secret-not-used-outside-tests'
  config.eager_load = true
  config.enable_reloading = false
  config.hosts = []
  config.logger = ActiveSupport::Ractors::Logger.new(ENV['RACTOR_DEBUG'] ? $stderr : nil)
  config.cache_store = :null_store
  config.public_file_server.enabled = false
  config.action_dispatch.show_exceptions = :none
  config.action_controller.allow_forgery_protection = false
  config.active_record.maintain_test_schema = false
  config.i18n.available_locales = %i[en fr]
end
RactorHost.config.root = ractor_directory
File.write("#{ractor_directory}/config/routes.rb",
           "Rails.application.routes.draw { mount_i18n_proofreading at: '/i18n_proofreading' }\n")
I18nProofreading.config.enabled_environments = %w[ractor] if I18nProofreading.config.respond_to?(:enabled_environments)
# A shareable test counter. Mutable storage lives on the main Ractor, so the
# test proves that successive worker Ractors share a rate-limit bucket.
class RactorCounter
  @counts = {}

  def self.increment(key, _amount = 1, **_options)
    if Ractor.main?
      @counts[key] = @counts.fetch(key, 0) + 1
    else
      shared_key = Ractor.make_shareable(key, copy: true)
      ActiveSupport::Ractors.on_main(self) { increment(shared_key) }
    end
  end
end

I18nProofreading.config.rate_limit = I18nProofreading.config.rate_limit.merge(store: RactorCounter, to: 2, by: lambda {
  request.remote_ip
})
RactorHost.initialize!
require_relative '../support/schema'

RactorUser = Data.define(:id, :email, :name)
I18nProofreading.configure do |config|
  config.enabled = ->(request) { request.get_header('HTTP_X_DISABLED') != 'yes' }
  config.authorize_admin = ->(request) { request.get_header('HTTP_X_ADMIN') == 'yes' }
  config.current_user = lambda { |request|
    RactorUser.new(id: request.get_header('HTTP_X_USER'), email: 'ractor@example.com', name: 'Ractor visitor')
  }
  config.enabled_environments = %w[ractor]
  config.on_submit = ->(suggestion) { suggestion.update_column(:author_label, "#{suggestion.author_label}:notified") }
end
Rails.application.ractorize!

class RactorRequestsTest < Minitest::Test
  def start_request(method, path, params: {}, headers: {})
    input = params.is_a?(String) ? params : Rack::Utils.build_nested_query(params)
    content_type = headers.fetch('CONTENT_TYPE', 'application/x-www-form-urlencoded')
    options = headers.merge(method: method, 'CONTENT_TYPE' => content_type,
                            'CONTENT_LENGTH' => input.bytesize.to_s)
    env = Rack::MockRequest.env_for(path, options)
    env.delete('rack.input')
    env.delete('rack.errors')
    Ractor.new(env, input) do |environment, data|
      environment['rack.input'] = StringIO.new(data)
      environment['rack.errors'] = StringIO.new
      status, response_headers, response_body = Rails.application.call(environment)
      body = +''
      response_body.each { |part| body << part }
      response_body.close if response_body.respond_to?(:close)
      [status, response_headers, body]
    end
  end

  def request(...) = start_request(...).value

  def test_rate_limit_counts_across_worker_ractors
    headers = { 'REMOTE_ADDR' => '198.51.100.42', 'HTTP_X_USER' => 'rate-user' }
    params = { suggestion: { translation_key: 'hello', locale: 'en', proposed_value: 'rate test' } }
    statuses = 3.times.map do
      request('POST', '/i18n_proofreading/suggestions', params: params, headers: headers).first
    end
    assert_equal [201, 201, 429], statuses
  end

  def test_simultaneous_worker_requests
    workers = 2.times.map { start_request('GET', '/i18n_proofreading/widget.js') }
    workers.each do |worker|
      status, _, body = worker.value
      assert_equal 200, status, body
    end
  end

  def test_assets_and_dashboard_render_in_non_main_ractors
    2.times do
      %w[widget.js dashboard.css].reject(&:empty?).each do |asset|
        status, headers, body = request('GET', "/i18n_proofreading/#{asset}")
        assert_equal 200, status, body
        refute_empty body
        assert_includes headers['content-type'], asset.end_with?('.css') ? 'css' : 'javascript'
      end
      status, _, body = request('GET', '/i18n_proofreading')
      assert_equal 403, status, body
      status, _, body = request('GET', '/i18n_proofreading', headers: { 'HTTP_X_ADMIN' => 'yes' })
      assert_equal 200, status, body
    end
  end

  def test_suggestions_resolve_identity_and_notification_callbacks
    attributes = { translation_key: 'hello', locale: 'en', old_value: 'Hello', proposed_value: 'Ractor hello' }
    status, _, body = request('POST', '/i18n_proofreading/suggestions',
                              params: { suggestion: attributes },
                              headers: { 'HTTP_X_USER' => 'alpha' })
    assert_equal 201, status, body
    suggestion = I18nProofreading::Suggestion.find_by!(proposed_value: 'Ractor hello')
    assert_equal 'alpha', suggestion.author_id
    assert_equal 'ractor@example.com:notified', suggestion.author_label
    status, _, body = request('GET', '/i18n_proofreading/suggestions/context?key=hello&locale=en')
    assert_equal 200, status, body
    assert_includes body, 'Ractor hello'
    status, _, body = request('POST', '/i18n_proofreading/suggestions', headers: { 'HTTP_X_DISABLED' => 'yes' })
    assert_equal 403, status, body
  end
end
