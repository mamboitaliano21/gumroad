# frozen_string_literal: true

class AddPausedUntilToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    change_table :subscriptions, bulk: true do |t|
      t.datetime :paused_until
      t.index :paused_until
    end
  end
end
