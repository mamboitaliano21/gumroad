# frozen_string_literal: true

class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.bigint :seller_id, null: false
      t.string :slug, limit: 8, null: false
      t.string :title, null: false
      t.text :content_html_raw, limit: 16.megabytes # mediumtext
      t.text :content_html_sanitized, limit: 16.megabytes # mediumtext
      t.boolean :published, null: false, default: false
      t.datetime :deleted_at
      t.json :settings_json

      t.timestamps

      t.index :seller_id
      t.index :slug, unique: true
      t.index :deleted_at
    end
  end
end
