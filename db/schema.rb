# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_24_000002) do
  create_table "dashboard_tiles", force: :cascade do |t|
    t.bigint "dashboard_id", null: false
    t.string "title"
    t.integer "row", default: 1, null: false
    t.integer "column", default: 1, null: false
    t.integer "width", default: 1, null: false
    t.integer "height", default: 1, null: false
    t.integer "position", default: 1, null: false
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id", "position"], name: "index_dashboard_tiles_on_dashboard_id_and_position"
    t.index ["dashboard_id"], name: "index_dashboard_tiles_on_dashboard_id"
  end

  create_table "dashboard_widgets", force: :cascade do |t|
    t.bigint "dashboard_tile_id", null: false
    t.bigint "device_capability_id"
    t.string "widget_type", null: false
    t.string "title"
    t.integer "position", default: 1, null: false
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_tile_id", "position"], name: "index_dashboard_widgets_on_dashboard_tile_id_and_position"
    t.index ["dashboard_tile_id"], name: "index_dashboard_widgets_on_dashboard_tile_id"
    t.index ["device_capability_id"], name: "index_dashboard_widgets_on_device_capability_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "context", null: false
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "context", "name"], name: "index_dashboards_on_user_context_name", unique: true
    t.index ["user_id"], name: "index_dashboards_on_user_id"
  end

  create_table "device_capabilities", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "capability_type", null: false
    t.json "configuration"
    t.json "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id", "key"], name: "index_device_capabilities_on_device_id_and_key", unique: true
    t.index ["device_id"], name: "index_device_capabilities_on_device_id"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "service_connection_id"
    t.bigint "parent_device_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "source_kind", default: "physical", null: false
    t.string "source_identifier"
    t.string "status", default: "unknown", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["key"], name: "index_devices_on_key", unique: true
    t.index ["parent_device_id"], name: "index_devices_on_parent_device_id"
    t.index ["service_connection_id", "source_identifier"], name: "index_devices_on_connection_and_source_identifier", unique: true, where: "(source_identifier IS NOT NULL)"
    t.index ["service_connection_id"], name: "index_devices_on_service_connection_id"
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "household_memberships", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "user_id"], name: "index_household_memberships_on_household_id_and_user_id", unique: true
    t.index ["household_id"], name: "index_household_memberships_on_household_id"
    t.index ["user_id"], name: "index_household_memberships_on_user_id"
  end

  create_table "households", force: :cascade do |t|
    t.integer "owner_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_households_on_owner_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.string "provider_key", null: false
    t.string "name"
    t.string "status", default: "connected", null: false
    t.text "encrypted_credentials"
    t.json "settings"
    t.text "last_error"
    t.datetime "last_verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_key"], name: "index_integrations_on_provider_key", unique: true
  end

  create_table "invites", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "created_by_id", null: false
    t.integer "accepted_by_id"
    t.string "token", null: false
    t.string "email"
    t.string "status", default: "pending", null: false
    t.integer "max_uses", default: 1, null: false
    t.integer "use_count", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_id"], name: "index_invites_on_accepted_by_id"
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["household_id"], name: "index_invites_on_household_id"
    t.index ["token"], name: "index_invites_on_token", unique: true
  end

  create_table "service_connections", force: :cascade do |t|
    t.bigint "service_provider_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "adapter", null: false
    t.string "base_url"
    t.string "credential_strategy", default: "environment", null: false
    t.string "status", default: "unknown", null: false
    t.text "last_error"
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_service_connections_on_key", unique: true
    t.index ["service_provider_id"], name: "index_service_connections_on_service_provider_id"
  end

  create_table "service_providers", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "provider_type", default: "integration", null: false
    t.text "description"
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_service_providers_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "avatar_url"
    t.string "google_uid"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
  end

  add_foreign_key "dashboard_tiles", "dashboards"
  add_foreign_key "dashboard_widgets", "dashboard_tiles"
  add_foreign_key "dashboard_widgets", "device_capabilities"
  add_foreign_key "dashboards", "users"
  add_foreign_key "device_capabilities", "devices"
  add_foreign_key "devices", "devices", column: "parent_device_id"
  add_foreign_key "devices", "service_connections"
  add_foreign_key "devices", "users"
  add_foreign_key "household_memberships", "households"
  add_foreign_key "household_memberships", "users"
  add_foreign_key "households", "users", column: "owner_id"
  add_foreign_key "invites", "households"
  add_foreign_key "invites", "users", column: "accepted_by_id"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "service_connections", "service_providers"
end
