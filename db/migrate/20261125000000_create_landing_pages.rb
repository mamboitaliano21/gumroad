# frozen_string_literal: true

class CreateLandingPages < ActiveRecord::Migration[7.1]
  def change
    create_table :landing_pages do |t|
      t.bigint   :product_id, null: false
      t.string   :slug, null: false, limit: 8
      t.string   :name
      t.text     :description
      t.string   :custom_summary
      t.json     :custom_attributes
      t.integer  :position, default: 0, null: false
      t.datetime :deleted_at
      t.timestamps

      t.index :product_id
      t.index :deleted_at
      t.index :slug, unique: true
    end
  end
end
