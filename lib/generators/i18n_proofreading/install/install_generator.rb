# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../migration_helpers'

module I18nProofreading
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include MigrationHelpers

      source_root File.expand_path('templates', __dir__)

      desc 'Installs i18n_proofreading: config initializer, migration, and engine mount.'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/i18n_proofreading.rb'
      end

      def create_suggestions_migration
        migration_template 'create_i18n_proofreading_suggestions.rb.tt',
                           'db/migrate/create_i18n_proofreading_suggestions.rb'
      end

      def mount_engine
        route %(mount_i18n_proofreading at: "/i18n_proofreading")
      end

      def post_install
        say "\ni18n_proofreading installed. Run `rails db:migrate`, then boot in development", :green
        say 'Optional: run `bin/rails i18n_proofreading:seed_demo` for sample suggestions.'
        say "and look for the “Suggest edits” pill in the bottom-left corner.\n"
      end
    end
  end
end
