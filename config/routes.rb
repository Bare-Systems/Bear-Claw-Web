Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get  "/login",                    to: "sessions#new",     as: :login
  post "/logout",                   to: "sessions#destroy", as: :logout
  get  "/auth/:provider/callback",  to: "sessions#create"
  get  "/auth/failure",             to: "sessions#failure"
  get  "/invites/:token/accept",    to: "sessions#accept_invite", as: :accept_invite
  get  "/dev/login",                to: "sessions#dev_login", as: :dev_login if Rails.env.development? || Rails.env.test?

  # Agent module — BearClaw chat, cron, memory
  namespace :agent do
    get "/",       to: "dashboard#index", as: :root
    resources :chat,   only: [ :index, :create ]
    resources :cron,   only: [ :index, :create, :update, :destroy ]
    resources :memory, only: [ :index, :destroy ]
  end

  # Security module — Ursa C2
  namespace :security do
    get "/",       to: "dashboard#index", as: :root
    resources :sessions, only: [ :index, :show ] do
      member do
        patch :context
        post :queue_task
        post :kill
      end
    end
    resources :tasks, only: [ :index, :show ]
    resources :campaigns, only: [ :index, :show ] do
      collection do
        get :playbooks
        post :save_playbook
        delete "playbooks/:name", action: :delete_playbook, as: :playbook
      end
      member do
        post :add_note
        delete "notes/:note_id", action: :delete_note, as: :note
        post :add_checklist_item
        patch "checklist/:item_id", action: :update_checklist_item, as: :checklist_item
        delete "checklist/:item_id", action: :delete_checklist_item
        patch :bulk_update_checklist
        post :apply_playbook
        post :snapshot_playbook
        get :handoff
      end
    end
    resources :governance, only: [ :index ] do
      collection do
        post "approvals/:approval_id/approve", action: :approve, as: :approve
        post "approvals/:approval_id/reject", action: :reject, as: :reject
        post :bulk_approvals
        post :upsert_policy
        delete "policy/:campaign", action: :delete_policy, as: :policy
        post :apply_remediation
        post :create_remediation_checklist
        get :report
      end
    end
    resources :events, only: [ :index ]
    resources :files, only: [ :index ] do
      member do
        get :download
      end
    end
    resources :users, only: [ :index, :create, :update ] do
      member do
        post :password
      end
    end
  end

  # Home module — Koala monitoring
  namespace :home do
    get "/",       to: "dashboard#index", as: :root
    resources :service_providers, only: [ :create, :update ]
    resources :service_connections, only: [ :create, :update ]
    resources :devices, only: [ :create, :update ]
    resources :device_capabilities, only: [ :create, :update ] do
      member do
        post :toggle
      end
    end
    resources :dashboard_tiles, path: "dashboard/tiles", only: [ :create, :update, :destroy ] do
      collection do
        post :apply_pack
      end
      resources :dashboard_widgets, path: "widgets", only: [ :create ]
    end
    resources :dashboard_layout_presets, path: "dashboard/layout_presets", only: [ :create, :destroy ], param: :name do
      collection do
        post :apply
      end
    end
    resource :dashboard_layout_history, path: "dashboard/layout_history", only: [], controller: :dashboard_layout_history do
      post :undo
    end
    resources :dashboard_widgets, path: "dashboard/widgets", only: [ :update, :destroy ]
    resources :cameras,  only: [ :index, :show ] do
      member do
        get :snapshot
      end
    end
    resources :zones,    only: [ :index, :show ]
    resources :packages, only: [ :index ]
    resources :firmware, only: [ :index ]
  end

  # Settings module — operator+ accessible, provider/integration management
  namespace :settings do
    get "/", to: "integrations#index", as: :root
    resources :integrations, only: [ :index, :create, :update, :destroy ]
  end

  # Finances module — Kodiak trading dashboard
  namespace :finances do
    get "/",          to: "dashboard#index",  as: :root
    get "/portfolio", to: "portfolio#index",  as: :portfolio
    resources :strategies, only: [ :index ] do
      member do
        post :pause
        post :resume
      end
    end
    resources :orders, only: [ :index, :destroy ]
    namespace :engine do
      get  "/",      to: "status#index", as: :root
      post "/start", to: "status#start", as: :start
      post "/stop",  to: "status#stop",  as: :stop
    end
  end

  # Admin module
  namespace :admin do
    get "/",       to: "dashboard#index", as: :root
    resources :users
    resources :invites, only: [:index, :create, :destroy]
    get :settings, to: "settings#index"
    get :audit,    to: "audit#index"
  end

  root "agent/dashboard#index"
end
