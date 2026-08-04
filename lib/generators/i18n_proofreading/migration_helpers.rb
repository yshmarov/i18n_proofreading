# frozen_string_literal: true

module I18nProofreading
  module Generators
    # Shared bits every migration-writing generator needs.
    module MigrationHelpers
      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end

      # Follow the host's own key type instead of forcing bigint, the same
      # `Rails.configuration.generators` lookup Rails' own Active Storage,
      # Action Text and Action Mailbox migrations do — so a host that set it
      # once gets consistent tables from all of them.
      #
      # Rendered as a `create_table` option rather than a bare value, because a
      # template is expanded at generate time: emitting the method name would
      # put `id: primary_key_type` in the migration, where nothing defines it.
      def primary_key_type_option
        config = Rails.configuration.generators
        type = config.options[config.orm][:primary_key_type]
        type ? ", id: :#{type}" : ''
      end
    end
  end
end
