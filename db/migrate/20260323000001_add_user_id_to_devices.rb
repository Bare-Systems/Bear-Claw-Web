class AddUserIdToDevices < ActiveRecord::Migration[8.0]
  def up
    add_column :devices, :user_id, :bigint
    add_index :devices, :user_id
    add_foreign_key :devices, :users

    # Assign all existing devices to Joe so they stay visible only to him.
    joe = User.find_by(email: "joseph.caruso.pc@gmail.com")
    execute("UPDATE devices SET user_id = #{joe.id}") if joe
  end

  def down
    remove_foreign_key :devices, :users
    remove_index :devices, :user_id
    remove_column :devices, :user_id
  end
end
