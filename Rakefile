# frozen_string_literal: true

require 'bundler/setup'
# Defines build/install/release — `rake release` is what the trusted-publishing
# workflow (.github/workflows/release.yml) runs to push the gem to RubyGems.
require 'bundler/gem_tasks'

require 'rake/testtask'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
  t.verbose = false
end

task default: :test
