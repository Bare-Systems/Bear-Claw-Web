class CreateIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :integrations do |t|
      # Which third-party provider this represents (govee, airthings, custom, …)
      t.string   :provider_key,       null: false
      # User-assigned label (defaults to provider name)
      t.string   :name
      # Connection health: connected | error | disconnected
      t.string   :status,             null: false, default: "connected"
      # Encrypted credential bag — stored as encrypted JSON, keyed by field name
      # (api_key, client_id, client_secret, url, token, …)
      t.text     :encrypted_credentials
      # Non-secret provider-specific config
      t.json     :settings
      # Last known error message from a sync attempt
      t.text     :last_error
      t.datetime :last_verified_at
      t.timestamps
    end

    add_index :integrations, :provider_key, unique: true
  end
end
