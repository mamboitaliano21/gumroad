# frozen_string_literal: true

class CreateApiEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :api_events do |t|
      t.references :user, null: false, index: true
      t.references :oauth_application, null: true, index: true
      t.string :event_type, null: false
      t.string :source, null: false # "cli", "api", "mobile"
      t.string :source_version # CLI version string, e.g. "1.2.3"
      t.string :controller_action, null: false # e.g. "links#create"
      t.json :metadata # flexible bag for additional context
      t.timestamps
    end

    add_index :api_events, [:user_id, :source, :created_at]
    add_index :api_events, [:source, :created_at]
  end
end
