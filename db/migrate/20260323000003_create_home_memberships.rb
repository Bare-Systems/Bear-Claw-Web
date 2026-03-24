class CreateHomeMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :household_memberships do |t|
      t.references :household, null: false, foreign_key: true
      t.references :user,      null: false, foreign_key: true
      t.string     :role,      null: false, default: "member"
      t.timestamps
    end
    add_index :household_memberships, [:household_id, :user_id], unique: true
  end
end
