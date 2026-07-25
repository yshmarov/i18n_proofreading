# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'rubocop', require: false
  gem 'sqlite3'

  # System tests drive the widget in a real (headless Chrome) browser.
  gem 'capybara'
  gem 'puma'
  gem 'selenium-webdriver'
end
