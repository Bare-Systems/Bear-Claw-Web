class CreateDashboardPlatform < ActiveRecord::Migration[8.0]
  def change
    create_table :service_providers do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :provider_type, null: false, default: "integration"
      t.text :description
      t.json :settings
      t.timestamps
    end
    add_index :service_providers, :key, unique: true

    create_table :service_connections do |t|
      t.references :service_provider, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :adapter, null: false
      t.string :base_url
      t.string :credential_strategy, null: false, default: "environment"
      t.string :status, null: false, default: "unknown"
      t.text :last_error
      t.json :settings
      t.timestamps
    end
    add_index :service_connections, :key, unique: true

    create_table :devices do |t|
      t.references :service_connection, foreign_key: true
      t.references :parent_device, foreign_key: { to_table: :devices }
      t.string :key, null: false
      t.string :name, null: false
      t.string :category, null: false
      t.string :source_kind, null: false, default: "physical"
      t.string :source_identifier
      t.string :status, null: false, default: "unknown"
      t.json :metadata
      t.timestamps
    end
    add_index :devices, :key, unique: true
    add_index :devices, [ :service_connection_id, :source_identifier ], unique: true, where: "source_identifier IS NOT NULL", name: "index_devices_on_connection_and_source_identifier"

    create_table :device_capabilities do |t|
      t.references :device, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :capability_type, null: false
      t.json :configuration
      t.json :state
      t.timestamps
    end
    add_index :device_capabilities, [ :device_id, :key ], unique: true

    create_table :dashboards do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :context, null: false
      t.json :settings
      t.timestamps
    end
    add_index :dashboards, [ :user_id, :context, :name ], unique: true, name: "index_dashboards_on_user_context_name"

    create_table :dashboard_tiles do |t|
      t.references :dashboard, null: false, foreign_key: true
      t.string :title
      t.integer :row, null: false, default: 1
      t.integer :column, null: false, default: 1
      t.integer :width, null: false, default: 1
      t.integer :height, null: false, default: 1
      t.integer :position, null: false, default: 1
      t.json :settings
      t.timestamps
    end
    add_index :dashboard_tiles, [ :dashboard_id, :position ]

    create_table :dashboard_widgets do |t|
      t.references :dashboard_tile, null: false, foreign_key: true
      t.references :device_capability, foreign_key: true
      t.string :widget_type, null: false
      t.string :title
      t.integer :position, null: false, default: 1
      t.json :settings
      t.timestamps
    end
    add_index :dashboard_widgets, [ :dashboard_tile_id, :position ]
  end
end
