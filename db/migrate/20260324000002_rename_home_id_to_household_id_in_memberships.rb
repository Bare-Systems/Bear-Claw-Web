class RenameHomeIdToHouseholdIdInMemberships < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:household_memberships, :home_id) && !column_exists?(:household_memberships, :household_id)
      rename_column :household_memberships, :home_id, :household_id
    end
  end

  def down
    if column_exists?(:household_memberships, :household_id)
      rename_column :household_memberships, :household_id, :home_id
    end
  end
end
