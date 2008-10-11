class CreateExchanges < ActiveRecord::Migration
  def self.up
    create_table :exchanges do |t|
      t.integer :customer_id
      t.integer :worker_id
      t.integer :req_id
      t.decimal :amount

      t.timestamps
    end
  end

  def self.down
    drop_table :exchanges
  end
end
