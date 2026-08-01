# frozen_string_literal: true

namespace :i18n_proofreading do
  desc 'Create or refresh i18n_proofreading demo suggestions'
  task seed_demo: :environment do
    suggestions = I18nProofreading::Seeds.load!
    puts "Seeded #{suggestions.size} i18n proofreading demo suggestions."
  end
end
