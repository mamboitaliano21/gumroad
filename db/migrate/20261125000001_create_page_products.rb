# frozen_string_literal: true

class CreatePageProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :page_products do |t|
      t.bigint :page_id, null: false
      t.bigint :product_id, null: false
      t.integer :position, null: false, default: 0

      t.timestamps

      t.index :page_id
      t.index :product_id
      t.index [:page_id, :product_id], unique: true, name: "index_page_products_on_page_and_product"
    end
  end
end
