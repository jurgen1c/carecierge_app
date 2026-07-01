require "rails_helper"

RSpec.describe "Localization baseline", type: :request do
  it "keeps English as the default locale and Spanish available" do
    expect(I18n.default_locale).to eq(:en)
    expect(I18n.available_locales).to include(:es, :en)
  end

  it "keeps Spanish validation messages available" do
    I18n.with_locale(:es) do
      user = User.new(email: "", password: "x", password_confirmation: "y")

      user.valid?

      expect(user.errors.full_messages).to include(
        "Correo electrónico no puede estar en blanco",
        "Contraseña es demasiado corta; mínimo 6 caracteres",
        "Confirmar contraseña no coincide con Contraseña"
      )

      create(:user, email: "taken@example.com")
      invalid_user = User.new(email: "not-an-email", password: "password123", password_confirmation: "password123")
      duplicate_user = User.new(email: "taken@example.com", password: "password123", password_confirmation: "password123")

      invalid_user.valid?
      duplicate_user.valid?

      expect(invalid_user.errors.full_messages).to include("Correo electrónico no es válido")
      expect(duplicate_user.errors.full_messages).to include("Correo electrónico ya está en uso")
    end
  end
end
