Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get  "/login",                    to: "sessions#new",     as: :login
  post "/logout",                   to: "sessions#destroy", as: :logout
  get  "/auth/:provider/callback",  to: "sessions#create"
  get  "/auth/failure",             to: "sessions#failure"

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
    resources :cameras,  only: [ :index, :show ]
    resources :zones,    only: [ :index, :show ]
    resources :packages, only: [ :index ]
    resources :firmware, only: [ :index ]
  end

  # Admin module
  namespace :admin do
    get "/",       to: "dashboard#index", as: :root
    resources :users
    get :settings, to: "settings#index"
    get :audit,    to: "audit#index"
  end

  root "agent/dashboard#index"
end
