# frozen_string_literal: true

require 'bundler/setup'
# Defines build/install/release — `rake release` is what the trusted-publishing
# workflow (.github/workflows/release.yml) runs to push the gem to RubyGems.
require 'bundler/gem_tasks'

require 'rake/testtask'

# Unit/integration tests — no browser, runs on every Ruby x Rails combo.
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb'].exclude('test/system/**/*')
  t.warning = false
  t.verbose = false
end

# System tests — drive the widget in headless Chrome (needs a browser).
Rake::TestTask.new('test:system') do |t|
  t.libs << 'test'
  t.test_files = FileList['test/system/**/*_test.rb']
  t.warning = false
  t.verbose = false
end

task default: :test
