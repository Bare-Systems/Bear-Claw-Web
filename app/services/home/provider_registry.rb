module Home
  # Static catalog of every third-party integration BearClaw supports.
  #
  # Each entry describes:
  #   key          — stable identifier, matches Integration#provider_key
  #   name         — display name shown in the UI
  #   tagline      — one-sentence description
  #   category     — grouping label (Smart Home, Air Quality, …)
  #   brand_color  — hex string used for the logo badge background
  #   brand_text   — hex string used for the logo letter/icon color
  #   logo_letter  — single character shown in the logo badge
  #   docs_url     — where a user goes to get their credentials
  #   backend      — which service handles syncing (:govee, :polar, :koala, :bearclaw_web)
  #   managed_by   — human label when credentials are not user-entered
  #   credential_fields — ordered list of form field descriptors
  #
  # credential_fields keys:
  #   key     — the hash key stored in Integration#credentials
  #   label   — form label
  #   type    — html input type (text | password | url | email)
  #   hint    — optional helper text shown below the field
  class ProviderRegistry
    PROVIDERS = [
      {
        key:          "govee",
        name:         "Govee",
        tagline:      "Sync lights, plugs, and sensors from your Govee account.",
        category:     "Smart Home",
        brand_color:  "#F59E0B",  # amber-500 — close to Govee's gold
        brand_text:   "#1C1917",
        logo_letter:  "G",
        docs_url:     "https://developer.govee.com/reference/apply-for-a-govee-developer-api-key",
        backend:      :govee,
        managed_by:   nil,
        credential_fields: [
          {
            key:   "api_key",
            label: "API Key",
            type:  "password",
            hint:  "Find your key in the Govee app under Profile → About Us → Apply for API Key."
          }
        ]
      },
      {
        key:          "airthings",
        name:         "Airthings",
        tagline:      "Monitor indoor air quality — radon, CO₂, VOC, humidity, and more.",
        category:     "Air Quality",
        brand_color:  "#06B6D4",  # cyan-500 — close to Airthings teal
        brand_text:   "#ecfeff",
        logo_letter:  "A",
        docs_url:     "https://dashboard.airthings.com",
        backend:      :polar,
        managed_by:   "Polar",   # credentials live in polar.env, not user-entered
        credential_fields: [
          {
            key:   "client_id",
            label: "Client ID",
            type:  "text",
            hint:  "From Airthings for Business dashboard → API clients."
          },
          {
            key:   "client_secret",
            label: "Client Secret",
            type:  "password",
            hint:  nil
          }
        ]
      },
      {
        key:          "custom",
        name:         "Custom",
        tagline:      "Connect any HTTP service using a base URL and bearer token.",
        category:     "Custom",
        brand_color:  "#6B7280",  # gray-500
        brand_text:   "#f9fafb",
        logo_letter:  "C",
        docs_url:     nil,
        backend:      :bearclaw_web,
        managed_by:   nil,
        credential_fields: [
          {
            key:   "url",
            label: "Base URL",
            type:  "url",
            hint:  "e.g. http://192.168.86.50:8080"
          },
          {
            key:   "token",
            label: "Bearer Token",
            type:  "password",
            hint:  nil
          }
        ]
      }
    ].map(&:freeze).freeze

    # Returns all provider descriptors.
    def self.all
      PROVIDERS
    end

    # Returns a single provider descriptor by key, or nil.
    def self.find(key)
      PROVIDERS.find { |p| p[:key] == key.to_s }
    end

    # Returns the list of providers the user can add/edit directly
    # (i.e. not fully managed by an external backend config).
    def self.user_configurable
      PROVIDERS.reject { |p| p[:managed_by].present? }
    end

    # Returns provider keys whose backend is :polar (so we know when to
    # show "managed by Polar" status instead of a credential form).
    def self.polar_managed_keys
      PROVIDERS.select { |p| p[:managed_by] == "Polar" }.map { |p| p[:key] }
    end
  end
end
