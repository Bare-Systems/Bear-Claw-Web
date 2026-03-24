class CreateInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :invites do |t|
      t.references :household,   null: false, foreign_key: true
      t.references :created_by,  null: false, foreign_key: { to_table: :users }
      t.references :accepted_by,             foreign_key: { to_table: :users }
      t.string     :token,       null: false
      t.string     :email
      t.string     :status,      null: false, default: "pending"
      t.integer    :max_uses,    null: false, default: 1
      t.integer    :use_count,   null: false, default: 0
      t.datetime   :expires_at
      t.datetime   :accepted_at
      t.timestamps
    end
    add_index :invites, :token, unique: true
  end
end
