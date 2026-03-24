class RenameHomesToHouseholds < ActiveRecord::Migration[8.0]
  def up
    # homes → households
    if table_exists?(:homes) && !table_exists?(:households)
      rename_table :homes, :households
    elsif !table_exists?(:households)
      create_table :households do |t|
        t.references :owner, null: false, foreign_key: { to_table: :users }
        t.string     :name,  null: false
        t.timestamps
      end
    end

    # home_memberships → household_memberships
    if table_exists?(:home_memberships) && !table_exists?(:household_memberships)
      rename_table :home_memberships, :household_memberships
    elsif !table_exists?(:household_memberships)
      create_table :household_memberships do |t|
        t.references :household, null: false, foreign_key: true
        t.references :user,      null: false, foreign_key: true
        t.string     :role,      null: false, default: "member"
        t.timestamps
      end
      add_index :household_memberships, [:household_id, :user_id], unique: true
    end

    # invites — rename home_id → household_id if needed, or create table
    if table_exists?(:invites)
      if column_exists?(:invites, :home_id) && !column_exists?(:invites, :household_id)
        rename_column :invites, :home_id, :household_id
      end
    else
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

  def down
    rename_table :households, :homes                       if table_exists?(:households)
    rename_table :household_memberships, :home_memberships if table_exists?(:household_memberships)
    rename_column :invites, :household_id, :home_id        if table_exists?(:invites) && column_exists?(:invites, :household_id)
  end
end
