# frozen_string_literal: true

class CreateNextcloudOfficeOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :nextcloud_office_operations do |t|
      t.bigint :user_id, null: false
      t.string :operation_key, limit: 128, null: false
      t.string :fingerprint, limit: 64, null: false
      t.text :target_path, null: false
      t.string :file_name, null: false
      t.string :file_type, limit: 4, null: false
      t.string :state, null: false, default: "pending"
      t.text :etag
      t.text :encrypted_result
      t.string :error_code
      t.datetime :completed_at
      t.timestamps null: false
    end
    add_index :nextcloud_office_operations,
              %i[user_id operation_key],
              unique: true,
              name: "idx_office_operations_user_key"
    add_index :nextcloud_office_operations, :target_path, unique: true
    add_index :nextcloud_office_operations, :completed_at
  end
end
