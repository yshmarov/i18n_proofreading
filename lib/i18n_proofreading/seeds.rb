# frozen_string_literal: true

module I18nProofreading
  module Seeds
    SUGGESTIONS = [
      {
        translation_key: 'dashboard.title',
        locale: 'en',
        old_value: 'Dashboard',
        proposed_value: 'Overview',
        comment: 'Shorter and clearer for the first screen.',
        page_url: '/dashboard',
        status: 'pending',
        author_id: 'i18n-proofreading-demo:reviewer',
        author_label: 'Demo Reviewer'
      },
      {
        translation_key: 'billing.cta',
        locale: 'en',
        old_value: 'Go',
        proposed_value: 'Update billing details',
        comment: 'The button should say what will happen.',
        page_url: '/billing',
        status: 'applied',
        author_id: 'i18n-proofreading-demo:copywriter',
        author_label: 'Demo Copywriter'
      },
      {
        translation_key: 'settings.cancel',
        locale: 'fr',
        old_value: 'Annuler',
        proposed_value: 'Supprimer le compte',
        comment: 'Rejected example: this changes the meaning.',
        page_url: '/settings',
        status: 'rejected',
        author_id: 'i18n-proofreading-demo:reviewer',
        author_label: 'Demo Reviewer'
      }
    ].freeze

    def self.load!
      SUGGESTIONS.map do |attributes|
        localized = attributes.merge(locale: locale_for(attributes.fetch(:locale)))
        suggestion = I18nProofreading::Suggestion.find_or_initialize_by(
          translation_key: localized.fetch(:translation_key),
          locale: localized.fetch(:locale),
          author_id: localized.fetch(:author_id)
        )
        suggestion.assign_attributes(localized)
        suggestion.save!
        suggestion
      end
    end

    def self.locale_for(preferred)
      locales = I18nProofreading.config.available_locales.call.map(&:to_s)
      return preferred if locales.include?(preferred)

      locales.first || I18n.default_locale.to_s
    end
    private_class_method :locale_for
  end
end
