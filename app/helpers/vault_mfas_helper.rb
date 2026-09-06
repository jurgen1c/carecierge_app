module VaultMfasHelper
  def vault_mfa_qr_data(secret, email)
    uri = ROTP::TOTP.new(secret, issuer: "Carecierge Vault").provisioning_uri(email)
    svg = RQRCode::QRCode.new(uri).as_svg(module_size: 4, offset: 16, fill: "ffffff", use_path: true)
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
