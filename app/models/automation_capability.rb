class AutomationCapability
  MODES = %w[disabled ask_every_time allow_automatically].freeze

  Definition = Data.define(:key, :group, :risk_level, :required_permissions) do
    def high_impact?
      risk_level == "high"
    end

    def allowed_modes
      high_impact? ? MODES.first(2) : MODES
    end
  end

  CATALOG = [
    Definition.new(key: "draft_messages", group: "everyday_help", risk_level: "low", required_permissions: %w[relationship_context]),
    Definition.new(key: "send_reminders", group: "everyday_help", risk_level: "low", required_permissions: %w[notifications]),
    Definition.new(key: "access_contacts", group: "everyday_help", risk_level: "medium", required_permissions: %w[contacts]),
    Definition.new(key: "access_calendar", group: "everyday_help", risk_level: "medium", required_permissions: %w[calendar]),
    Definition.new(key: "suggest_gifts", group: "everyday_help", risk_level: "low", required_permissions: %w[relationship_context]),
    Definition.new(key: "contact_vendors", group: "external_actions", risk_level: "medium", required_permissions: %w[vendor_communication]),
    Definition.new(key: "send_invitations", group: "external_actions", risk_level: "medium", required_permissions: %w[external_communication calendar]),
    Definition.new(key: "make_reservations", group: "external_actions", risk_level: "medium", required_permissions: %w[vendor_communication calendar]),
    Definition.new(key: "make_purchases", group: "sensitive_actions", risk_level: "high", required_permissions: %w[payment_method]),
    Definition.new(key: "pay_deposits", group: "sensitive_actions", risk_level: "high", required_permissions: %w[payment_method]),
    Definition.new(key: "analyze_uploaded_social_content", group: "sensitive_actions", risk_level: "medium", required_permissions: %w[uploaded_social_content])
  ].freeze

  INDEX = CATALOG.index_by(&:key).freeze

  def self.all
    CATALOG
  end

  def self.fetch(key)
    INDEX.fetch(key.to_s)
  end
end
