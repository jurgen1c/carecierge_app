class AutomationPermissionDecision
  attr_reader :capability, :mode

  def initialize(capability:, mode:)
    @capability = capability
    @mode = mode.to_s
  end

  def enabled?
    mode != "disabled"
  end

  def approval_required?
    capability.high_impact? || mode == "ask_every_time"
  end

  def permits_execution?(explicitly_approved: false)
    return false unless enabled?
    return explicitly_approved == true if approval_required?

    mode == "allow_automatically"
  end
end
