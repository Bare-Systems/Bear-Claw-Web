module Home
  class CapabilityWidgetCatalog
    Entry = Struct.new(:type, :label, :description, keyword_init: true)

    CATALOG = {
      "camera_feed" => [
        Entry.new(type: "camera_feed", label: "Live Camera Feed", description: "Refreshes the latest camera frame from Koala."),
        Entry.new(type: "status_badge", label: "Camera Status", description: "Shows camera health, source, and recent probe state.")
      ],
      "switch" => [
        Entry.new(type: "switch_control", label: "Switch Control", description: "Toggles a binary device state."),
        Entry.new(type: "status_badge", label: "Switch Status", description: "Shows current switch availability and state.")
      ],
      "sensor" => [
        Entry.new(type: "sensor_stat",      label: "Sensor Reading",   description: "Displays the latest sensor value."),
        Entry.new(type: "air_quality_stat", label: "Air Quality Card", description: "Shows metric value with colour-coded health threshold bands and a proportional gauge."),
        Entry.new(type: "status_badge",     label: "Sensor Status",    description: "Shows connectivity and freshness.")
      ],
      "status" => [
        Entry.new(type: "status_badge",   label: "Status Card",      description: "Displays device health and metadata."),
        Entry.new(type: "security_stat",  label: "Security Counter", description: "Shows session or campaign count with status badge.")
      ],
      "finance" => [
        Entry.new(type: "portfolio_stat", label: "Portfolio Value",  description: "Displays a USD-formatted portfolio metric with trend coloring."),
        Entry.new(type: "sensor_stat",    label: "Raw Value",        description: "Shows the raw numeric value and unit.")
      ]
    }.freeze

    def self.allowed_widgets_for(capability_type)
      entries_for(capability_type).map(&:type)
    end

    def self.default_widget_type_for(capability_type)
      entries_for(capability_type).first&.type || "status_badge"
    end

    def self.options_for_select(capability_type = nil)
      entries = capability_type.present? ? entries_for(capability_type) : CATALOG.values.flatten
      entries.map { |entry| [ entry.label, entry.type ] }
    end

    def self.entries_for(capability_type)
      CATALOG.fetch(capability_type.to_s, CATALOG.fetch("status"))
    end
  end
end
