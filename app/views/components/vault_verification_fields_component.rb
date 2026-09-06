class VaultVerificationFieldsComponent < ApplicationViewComponent
  option :form
  option :password, default: -> { true }
  option :second_factor, default: -> { true }
  option :totp_only, default: -> { false }
  option :required, default: -> { true }
  option :description_id, default: -> { "vault-mfa-error" }

  style :input do
    base { %w[mt-2 min-h-11 w-full rounded-lg border border-private-line bg-canvas px-3 py-2 text-base text-ink focus:outline-2 focus:outline-offset-2 focus:outline-primary] }
  end

  style :label do
    base { %w[block text-sm font-semibold text-ink] }
  end
end
