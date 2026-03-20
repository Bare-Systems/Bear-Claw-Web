module ApplicationHelper
  def ursa_timestamp(timestamp)
    return "never" if timestamp.blank?

    Time.zone.at(timestamp.to_f).strftime("%Y-%m-%d %H:%M:%S")
  end

  def ursa_time_ago(timestamp)
    return "never" if timestamp.blank?

    distance_in_words_to_now(Time.zone.at(timestamp.to_f), include_seconds: true) + " ago"
  end

  def ursa_filesize(size)
    return "0 B" if size.blank?

    units = %w[B KB MB GB TB]
    value = size.to_f
    index = 0
    while value >= 1024 && index < units.length - 1
      value /= 1024.0
      index += 1
    end

    index.zero? ? "#{value.to_i} #{units[index]}" : format("%.1f %s", value, units[index])
  end

  def ursa_status_classes(status)
    case status.to_s
    when "active", "completed", "approved", "done"
      "bg-emerald-950 text-emerald-300 border border-emerald-800/60"
    when "stale", "pending", "in_progress", "warning", "medium"
      "bg-amber-950 text-amber-300 border border-amber-800/60"
    when "dead", "error", "rejected", "critical", "high", "blocked"
      "bg-red-950 text-red-300 border border-red-800/60"
    else
      "bg-gray-900 text-gray-300 border border-gray-800"
    end
  end

  def ursa_risk_classes(risk_level)
    ursa_status_classes(risk_level)
  end

  def ursa_parse_json(value)
    return value if value.is_a?(Hash)
    return {} if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    {}
  end
end
