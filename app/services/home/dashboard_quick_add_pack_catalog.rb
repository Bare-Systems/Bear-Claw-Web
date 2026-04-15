module Home
  class DashboardQuickAddPackCatalog
    Pack = Struct.new(:key, :label, :description, :items, keyword_init: true)
    Item = Struct.new(:capability, :widget_type, :title, :section, :width, :height, :settings, keyword_init: true)

    def initialize(capabilities:)
      @capabilities = Array(capabilities)
    end

    def available_packs
      [
        build_camera_wall_pack,
        build_air_quality_strip_pack,
        build_security_pulse_pack,
        build_portfolio_pulse_pack
      ].compact
    end

    def pack(key)
      available_packs.find { |entry| entry.key == key.to_s }
    end

    private

    def build_camera_wall_pack
      capabilities = capabilities_for("camera_feed", preferred_provider: "koala").first(4)
      return nil if capabilities.empty?

      Pack.new(
        key: "camera_wall",
        label: "Camera Wall",
        description: "Adds up to four live camera tiles sized for fast visual scanning.",
        items: capabilities.map do |capability|
          Item.new(
            capability: capability,
            widget_type: "camera_feed",
            title: capability.device.name,
            section: "Cameras",
            width: 4,
            height: 3,
            settings: { "refresh_interval_seconds" => 4 }
          )
        end
      )
    end

    def build_air_quality_strip_pack
      capabilities = capabilities_for("sensor", preferred_provider: "polar").first(3)
      return nil if capabilities.empty?

      Pack.new(
        key: "air_quality_strip",
        label: "Air Quality Strip",
        description: "Creates compact air quality cards for the latest sensor metrics.",
        items: capabilities.map do |capability|
          Item.new(
            capability: capability,
            widget_type: "air_quality_stat",
            title: capability.name,
            section: "Air",
            width: 2,
            height: 2,
            settings: {}
          )
        end
      )
    end

    def build_security_pulse_pack
      capabilities = capabilities_for("status", preferred_provider: "ursa").first(2)
      return nil if capabilities.empty?

      Pack.new(
        key: "security_pulse",
        label: "Security Pulse",
        description: "Pins the most important security counters into a compact overview.",
        items: capabilities.map do |capability|
          Item.new(
            capability: capability,
            widget_type: "security_stat",
            title: capability.name,
            section: "Security",
            width: 2,
            height: 2,
            settings: {}
          )
        end
      )
    end

    def build_portfolio_pulse_pack
      capabilities = capabilities_for("finance", preferred_provider: "kodiak").first(3)
      return nil if capabilities.empty?

      Pack.new(
        key: "portfolio_pulse",
        label: "Portfolio Pulse",
        description: "Adds a compact portfolio snapshot with the highest-signal finance metrics.",
        items: capabilities.map do |capability|
          Item.new(
            capability: capability,
            widget_type: "portfolio_stat",
            title: capability.name,
            section: "Trading",
            width: 2,
            height: 2,
            settings: {}
          )
        end
      )
    end

    def capabilities_for(capability_type, preferred_provider:)
      @capabilities
        .select { |capability| capability.capability_type == capability_type }
        .sort_by do |capability|
          [
            capability.service_provider&.key == preferred_provider ? 0 : 1,
            capability.device.name.to_s,
            capability.name.to_s
          ]
        end
    end
  end
end
