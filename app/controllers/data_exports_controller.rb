class DataExportsController < ApplicationController
  FORMATS = %w[json csv pdf ics].freeze
  SCOPES = %w[account relationship_profile].freeze

  rate_limit to: 10, within: 1.minute, by: -> { "#{current_user.id}:#{request.remote_ip}" }

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    authorize :data_control, :create?
    return render_controls_error(t("data_exports.errors.invalid_request")) unless valid_request?
    profile = selected_profile
    result = DataExports::Prepare.call(user: current_user, relationship_profile: profile, format: export_format,
      include_sensitive: include_sensitive?, password: export_params[:current_password], code: export_params[:code])
    if result.error
      key = result.error == :password_required ? "data_exports.errors.password_required" : "vault_mfa.errors.#{result.error}"
      return render_controls_error(t(key))
    end

    content, media_type, extension = if export_format == "ics"
      serialize_calendar(profile:)
    else
      serialize(result.snapshot)
    end

    AuditEvent.record!(
      user: current_user,
      actor: current_user,
      action: "data_export.requested",
      target: profile || current_user,
      metadata: { request_kind: "#{export_scope}_#{export_format}", result: "completed" }
    )

    response.headers["Cache-Control"] = "no-store"
    send_data content,
      type: media_type,
      disposition: "attachment",
      filename: "carecierge-#{export_scope.dasherize}-#{Time.current.to_date}.#{extension}"
  end

  private

  def export_params
    @export_params ||= params.require(:data_export).permit(
      :scope,
      :format,
      :relationship_profile_id,
      :include_sensitive,
      :current_password,
      :code
    )
  end

  def export_scope
    export_params[:scope].to_s
  end

  def export_format
    export_params[:format].to_s
  end

  def valid_request?
    SCOPES.include?(export_scope) && FORMATS.include?(export_format) &&
      (export_scope != "relationship_profile" || export_params[:relationship_profile_id].present?)
  end

  def selected_profile
    return unless export_scope == "relationship_profile"

    current_user.relationship_profiles.with_discarded.find(export_params[:relationship_profile_id])
  end

  def include_sensitive?
    ActiveModel::Type::Boolean.new.cast(export_params[:include_sensitive])
  end

  def serialize(snapshot)
    case export_format
    when "json"
      [ JSON.pretty_generate(snapshot.as_json), "application/json", "json" ]
    when "csv"
      [ DataExports::CsvSerializer.new(snapshot).to_csv, "text/csv", "csv" ]
    when "pdf"
      html = render_to_string(template: "data_exports/summary", layout: false, locals: { snapshot: })
      pdf = FerrumPdf.render_pdf(
        html:,
        display_url: trusted_display_url,
        pdf_options: { format: "A4", print_background: true }
      )
      [ pdf, "application/pdf", "pdf" ]
    end
  end

  def serialize_calendar(profile:)
    reminders = profile ? profile.reminders : current_user.reminders
    important_dates = profile ? profile.important_dates : ImportantDate.where(relationship_profile: current_user.relationship_profiles.with_discarded)
    calendar = DataExports::CalendarSerializer.new(reminders:, important_dates:).to_ical
    [ calendar, "text/calendar", "ics" ]
  end

  def trusted_display_url
    options = Rails.application.config.action_mailer.default_url_options
    protocol = options.fetch(:protocol, "https").to_s.delete_suffix("://")
    port = options[:port].presence
    "#{protocol}://#{options.fetch(:host)}#{":#{port}" if port}"
  end

  def render_controls_error(message)
    @relationship_profiles = current_user.relationship_profiles.with_discarded.ordered
    flash.now[:alert] = message
    response.headers["Cache-Control"] = "no-store"
    render "data_controls/show", status: :unprocessable_content
  end
end
