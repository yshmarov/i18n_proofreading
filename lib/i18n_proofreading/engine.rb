# frozen_string_literal: true

module I18nProofreading
  class Engine < ::Rails::Engine
    isolate_namespace I18nProofreading

    initializer 'i18n_proofreading.middleware' do |app|
      app.middleware.use I18nProofreading::Middleware
    end

    # Prepend the key-marking backend once the app (and its I18n backend) is up,
    # and only in an enabled environment, so production never carries the patch.
    config.after_initialize do
      if I18nProofreading.config.environment_enabled? &&
         !I18n.backend.class.include?(I18nProofreading::Marking::Backend)
        I18n.backend.class.prepend(I18nProofreading::Marking::Backend)
      end
    end

    initializer 'i18n_proofreading.helper' do
      ActiveSupport.on_load(:action_view) do
        include I18nProofreading::TagHelper
      end
    end

    initializer 'i18n_proofreading.routing' do
      ActionDispatch::Routing::Mapper.include(Module.new do
        def mount_i18n_proofreading(at: I18nProofreading.config.mount_path, **options)
          I18nProofreading.config.mount_path = at
          mount I18nProofreading::Engine, at:, **options
        end
      end)
    end
  end
end
