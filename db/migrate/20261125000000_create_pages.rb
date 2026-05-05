# frozen_string_literal: true

class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.bigint :seller_id, null: false
      t.string :permalink, null: false
      t.string :title, null: false, default: "Untitled page"
      t.text :raw_html, size: :long
      t.text :sanitized_html, size: :long
      t.text :compiled_css, size: :long
      t.datetime :deleted_at
      t.timestamps

      t.index :seller_id
      t.index :deleted_at
      t.index :permalink, unique: true
    end
  end
end
