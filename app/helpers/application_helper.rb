module ApplicationHelper
  include ActionView::Helpers::DateHelper

  def ursa_timestamp(timestamp)
    return "never" if timestamp.blank?

    t = ursa_parse_time(timestamp)
    t ? t.strftime("%Y-%m-%d %H:%M:%S") : timestamp.to_s
  end

  def ursa_time_ago(timestamp)
    return "never" if timestamp.blank?

    t = ursa_parse_time(timestamp)
    return timestamp.to_s unless t

    distance_of_time_in_words_to_now(t, include_seconds: true) + " ago"
  end

  def ursa_parse_time(timestamp)
    return nil if timestamp.blank?

    timestamp.is_a?(Numeric) ? Time.zone.at(timestamp) : Time.zone.parse(timestamp.to_s)
  rescue ArgumentError, TypeError
    nil
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

  def bearclaw_chat_widget_enabled?
    current_user&.can_access?(:agent)
  end

  def bearclaw_chat_widget_embedded?
    controller_path == "agent/chat" && action_name == "index"
  end

  def bearclaw_run_status_classes(status)
    case status.to_s
    when "done"
      "bg-emerald-950 text-emerald-300 border border-emerald-800/60"
    when "error"
      "bg-red-950 text-red-300 border border-red-800/60"
    else
      "bg-sky-950 text-sky-300 border border-sky-800/60"
    end
  end

  def bearclaw_run_timestamp(timestamp)
    return "—" if timestamp.blank?

    Time.zone.at(timestamp.to_i).strftime("%Y-%m-%d %H:%M:%S")
  rescue ArgumentError, TypeError
    timestamp.to_s
  end

  def bearclaw_run_event_classes(event_type)
    case event_type.to_s
    when "prompt"
      "border-cyan-800/50 bg-cyan-950/20"
    when "tool_call"
      "border-amber-800/50 bg-amber-950/20"
    when "tool_result"
      "border-emerald-800/50 bg-emerald-950/20"
    when "model_output", "done"
      "border-violet-800/50 bg-violet-950/20"
    when "error"
      "border-red-800/50 bg-red-950/20"
    else
      "border-gray-800 bg-gray-950/40"
    end
  end

  def bearclaw_run_event_title(event)
    case event["type"].to_s
    when "prompt"
      "Prompt"
    when "tool_call"
      "Tool Call"
    when "tool_result"
      "Tool Result"
    when "model_output"
      "Model Output"
    when "done"
      "Run Complete"
    when "error"
      "Error"
    else
      event["type"].to_s.tr("_", " ").titleize
    end
  end

  def bearclaw_run_event_lines(event)
    lines = []
    lines << [ "Tool", event["tool"] ] if event["tool"].present?
    lines << [ "Arguments", event["arguments"] ] if event["arguments"].present?
    lines << [ "Content", event["content"] ] if event["content"].present?
    lines << [ "Message", event["message"] ] if event["message"].present?
    lines << [ "Code", event["code"] ] if event["code"].present?
    lines << [ "Success", event["success"] ? "true" : "false" ] if event.key?("success")
    lines
  end

  def bearclaw_transcript_timestamp(timestamp)
    bearclaw_run_timestamp(timestamp)
  end

  def bearclaw_transcript_body(value)
    return "—" if value.blank?

    parsed = JSON.parse(value)
    JSON.pretty_generate(parsed)
  rescue JSON::ParserError
    value.to_s
  end
end
