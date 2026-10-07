# frozen_string_literal: true

ActiveRecord::Schema.define(version: 0) do
  create_table :users do |t|
    t.string :email
    t.timestamps
  end

  create_table :hotwire_native_shell_device_tokens do |t|
    t.string :token, null: false
    t.string :provider, null: false
    t.string :platform
    t.string :owner_type
    t.integer :owner_id
    t.datetime :last_seen_at
    t.timestamps
  end

  add_index :hotwire_native_shell_device_tokens, :token, unique: true
  add_index :hotwire_native_shell_device_tokens, [ :owner_type, :owner_id ], name: "index_shell_device_tokens_on_owner"
end
