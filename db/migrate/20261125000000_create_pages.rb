# frozen_string_literal: true

class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages do |t|
      t.bigint :seller_id, null: false
      t.string :unique_permalink, null: false
      t.string :title, null: false
      t.text :raw_html, size: :long
      t.text :sanitized_html, size: :long
      t.datetime :unpublished_at
      t.datetime :deleted_at
      t.timestamps

      t.index [:seller_id, :deleted_at]
      t.index :unique_permalink, unique: true
    end
  end
end
