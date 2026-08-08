# frozen_string_literal: true

module I18nProofreading
  module Seeds
    SUGGESTIONS = [
      {
        translation_key: 'dashboard.title',
        locale: 'en',
        old_value: 'Dashboard',
        proposed_value: 'Product overview',
        comment: 'Start here: pending suggestions are the review inbox. Compare the rendered wording and ' \
                 'page context, then decide whether the proposed copy belongs in your locale file.',
        page_url: '/dashboard',
        status: 'pending',
        author_id: 'i18n-proofreading-demo:reviewer',
        author_label: 'Demo reviewer · needs a decision'
      },
      {
        translation_key: 'billing.cta',
        locale: 'en',
        old_value: 'Go',
        proposed_value: 'Update billing details',
        comment: 'Applied is bookkeeping, not automation: a maintainer copied this clearer call to action ' \
                 'into config/locales and committed the change. The gem never edits YAML for you.',
        page_url: '/billing',
        status: 'applied',
        author_id: 'i18n-proofreading-demo:copywriter',
        author_label: 'Demo copywriter · applied by a human'
      },
      {
        translation_key: 'settings.cancel',
        locale: 'fr',
        old_value: 'Annuler',
        proposed_value: 'Supprimer le compte',
        comment: 'Rejected on purpose: the proposal means “Delete the account,” not “Cancel.” The original ' \
                 'translation stays the source of truth, and the rejected row preserves the review decision.',
        page_url: '/settings',
        status: 'rejected',
        author_id: 'i18n-proofreading-demo:reviewer',
        author_label: 'Demo reviewer · meaning changed'
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
