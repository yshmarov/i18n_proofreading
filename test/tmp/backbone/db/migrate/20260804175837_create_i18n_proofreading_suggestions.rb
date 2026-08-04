# frozen_string_literal: true

class CreateI18nProofreadingSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :i18n_proofreading_suggestions do |t|
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

    add_index :i18n_proofreading_suggestions, %i[translation_key locale]
    add_index :i18n_proofreading_suggestions, :status
  end
end
