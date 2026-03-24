module Home
  # Provider-agnostic presentation layer for sensor metric capabilities.
  #
  # Any service (Polar, Airthings, Purple Air, etc.) that normalises its
  # readings into the standard DeviceCapability state schema:
  #
  #   state: { value:, unit:, display_value:, quality:, status:, last_seen_at: }
  #   configuration: { metric:, scope:, domain: }
  #
  # will automatically gain proper icons, colour-coded threshold bands, and a
  # proportional gauge bar by adding its metric name to THRESHOLDS below.
  class MetricPresenter
    # ── Icons ───────────────────────────────────────────────────────────────
    ICONS = {
      "temperature" => "🌡",
      "humidity"    => "💧",
      "co2"         => "💨",
      "voc"         => "🫧",
      "radon"       => "☢",
      "pm2.5"       => "🔬"
    }.freeze

    # ── Threshold bands per metric ───────────────────────────────────────────
    # gauge: defines the numeric range used to draw the proportional bar.
    # bands: ordered list of upper bounds; first matching band wins.
    #
    # Radon values are in Bq/m³ (as reported by Airthings via Polar).
    #   WHO action level: 300 Bq/m³   EPA action level: 148 Bq/m³
    THRESHOLDS = {
      "temperature" => {
        gauge: { min: 10.0, max: 35.0 },
        bands: [
          { max: 16.0,          label: "Cold",        color: :amber   },
          { max: 26.0,          label: "Comfortable", color: :emerald },
          { max: Float::INFINITY, label: "Warm",      color: :amber   }
        ]
      },
      "humidity" => {
        gauge: { min: 0.0, max: 100.0 },
        bands: [
          { max: 30.0,          label: "Too Dry",   color: :amber   },
          { max: 60.0,          label: "Ideal",     color: :emerald },
          { max: Float::INFINITY, label: "Too Humid", color: :amber }
        ]
      },
      "co2" => {
        gauge: { min: 400.0, max: 2500.0 },
        bands: [
          { max: 800.0,         label: "Excellent",  color: :emerald },
          { max: 1000.0,        label: "Good",       color: :emerald },
          { max: 1500.0,        label: "Fair",       color: :amber   },
          { max: 2000.0,        label: "Poor",       color: :orange  },
          { max: Float::INFINITY, label: "Hazardous", color: :red   }
        ]
      },
      "voc" => {
        gauge: { min: 0.0, max: 5000.0 },
        bands: [
          { max: 250.0,         label: "Excellent",  color: :emerald },
          { max: 2000.0,        label: "Good",       color: :emerald },
          { max: 4000.0,        label: "Fair",       color: :amber   },
          { max: Float::INFINITY, label: "Poor",     color: :red     }
        ]
      },
      "radon" => {
        gauge: { min: 0.0, max: 1000.0 },
        bands: [
          { max: 100.0,         label: "Low",        color: :emerald },
          { max: 148.0,         label: "Moderate",   color: :amber   },
          { max: 300.0,         label: "Elevated",   color: :orange  },
          { max: Float::INFINITY, label: "High",     color: :red     }
        ]
      },
      "pm2.5" => {
        gauge: { min: 0.0, max: 100.0 },
        bands: [
          { max: 12.0,          label: "Good",       color: :emerald },
          { max: 35.0,          label: "Moderate",   color: :amber   },
          { max: 55.0,          label: "Sensitive",  color: :orange  },
          { max: Float::INFINITY, label: "Unhealthy", color: :red    }
        ]
      }
    }.freeze

    # ── Tailwind class bundles per colour token ──────────────────────────────
    # All class names are complete string literals so Tailwind's content
    # scanner includes them in the production build.
    COLORS = {
      emerald: {
        value:        "text-emerald-400",
        gauge_fill:   "bg-emerald-500",
        badge_bg:     "bg-emerald-950/60",
        badge_text:   "text-emerald-300",
        badge_border: "border-emerald-800/60"
      },
      amber: {
        value:        "text-amber-400",
        gauge_fill:   "bg-amber-500",
        badge_bg:     "bg-amber-950/60",
        badge_text:   "text-amber-300",
        badge_border: "border-amber-800/60"
      },
      orange: {
        value:        "text-orange-400",
        gauge_fill:   "bg-orange-500",
        badge_bg:     "bg-orange-950/60",
        badge_text:   "text-orange-300",
        badge_border: "border-orange-800/60"
      },
      red: {
        value:        "text-red-400",
        gauge_fill:   "bg-red-500",
        badge_bg:     "bg-red-950/60",
        badge_text:   "text-red-300",
        badge_border: "border-red-800/60"
      },
      gray: {
        value:        "text-gray-300",
        gauge_fill:   "bg-gray-600",
        badge_bg:     "bg-gray-800/60",
        badge_text:   "text-gray-400",
        badge_border: "border-gray-700/60"
      }
    }.freeze

    # ── Public interface ─────────────────────────────────────────────────────

    def initialize(capability)
      @capability = capability
      @state      = capability.state_hash
      @config     = capability.configuration_hash
      @metric     = @config["metric"].to_s
    end

    def icon
      ICONS.fetch(@metric, "📊")
    end

    def label
      @capability.name
    end

    # "Indoor" / "Outdoor" / nil
    def scope_label
      s = @config["scope"].to_s.strip
      s.presence&.capitalize
    end

    # Formatted reading; falls back through display_value → formatted numeric → em-dash
    def display_value
      @state["display_value"].presence || formatted_numeric || "—"
    end

    def unit
      @state["unit"].to_s
    end

    def quality
      @state["quality"].to_s
    end

    # Human-readable quality / threshold band label
    def threshold_label
      active_band ? active_band[:label] : quality_fallback_label
    end

    # Resolved colour token (Symbol) for the current reading
    def color
      active_band ? active_band[:color] : quality_fallback_color
    end

    # Complete Tailwind class for the large numeric value
    def value_color_class
      COLORS.dig(color, :value) || COLORS.dig(:gray, :value)
    end

    # Space-joined badge classes (bg + text + border)
    def quality_badge_class
      c = COLORS.fetch(color, COLORS[:gray])
      "#{c[:badge_bg]} #{c[:badge_text]} #{c[:badge_border]}"
    end

    # Complete Tailwind class for the gauge fill bar
    def gauge_fill_class
      COLORS.dig(color, :gauge_fill) || COLORS.dig(:gray, :gauge_fill)
    end

    # Integer 0-100, or nil when no gauge scale is defined for this metric
    def gauge_pct
      spec = THRESHOLDS.dig(@metric, :gauge)
      return nil unless spec && numeric_value

      min, max = spec[:min].to_f, spec[:max].to_f
      range = max - min
      return 0 if range <= 0

      ((numeric_value.to_f - min) / range * 100).clamp(2, 100).round
    end

    # Short timestamp for the footer ("3:47 PM" or "No reading")
    def formatted_timestamp
      raw = @state["last_seen_at"].presence
      return "No reading" unless raw

      begin
        Time.parse(raw).strftime("%-I:%M %p")
      rescue ArgumentError, TypeError
        raw
      end
    end

    # Normalised status string for external use (e.g. ursa_status_classes)
    def status
      @state["status"].presence || @capability.status_label || "unknown"
    end

    private

    def numeric_value
      @numeric_value ||= @state["value"].presence&.to_f
    end

    # Metric-specific numeric formatting — one decimal for continuous readings,
    # integer for counts/concentrations where fractional precision adds no meaning.
    def formatted_numeric
      return nil unless numeric_value

      case @metric
      when "temperature" then format("%.1f", numeric_value)
      when "pm2.5"       then format("%.1f", numeric_value)
      when "humidity"    then format("%.0f", numeric_value)
      when "co2"         then format("%.0f", numeric_value)
      when "voc"         then format("%.0f", numeric_value)
      when "radon"       then format("%.0f", numeric_value)
      else                    numeric_value.to_s
      end
    end

    def active_band
      return @active_band if defined?(@active_band)

      bands = THRESHOLDS.dig(@metric, :bands)
      @active_band = bands && numeric_value ? bands.find { |b| numeric_value <= b[:max] } : nil
    end

    def quality_fallback_label
      case quality
      when "good"        then "Good"
      when "estimated"   then "Estimated"
      when "outlier"     then "Outlier"
      when "unavailable" then "No Reading"
      else                    "Unknown"
      end
    end

    def quality_fallback_color
      case quality
      when "good"        then :emerald
      when "estimated"   then :amber
      when "outlier"     then :orange
      when "unavailable" then :gray
      else                    :gray
      end
    end
  end
end
