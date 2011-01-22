class AddNotifications < ActiveRecord::Migration
  def self.up
    # guard to prevent this renamed migration from running again
    return true if Person.new.respond_to?(:notifications)
    add_column :people, :notifications, :boolean, :default => true
    add_column :people, :active, :boolean, :default => true
    add_column :offers, :notifications, :boolean, :default => true
    add_column :offers, :active, :boolean, :default => true
  end

  def self.down
    remove_column :people, :notifications
    remove_column :people, :active
    remove_column :offers, :notifications
    remove_column :offers, :active
  end
end
