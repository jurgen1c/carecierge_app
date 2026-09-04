class AddLocaleToCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_connections, :locale, :string, null: false, default: "en"
    add_check_constraint :calendar_connections,
      "locale IN ('en', 'es')",
      name: "calendar_connections_supported_locale"
  end
end
