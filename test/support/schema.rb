# frozen_string_literal: true

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :i18n_proofreading_suggestions, force: true do |t|
    t.string :translation_key, null: false
    t.string :locale, null: false
    t.text :old_value
    t.text :proposed_value, null: false
    t.text :comment
    t.string :page_url
    t.string :status, null: false, default: 'pending'
    t.string :author_id
    t.string :author_label
    t.timestamps
  end
end
