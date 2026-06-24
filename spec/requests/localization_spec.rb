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
        "Correo electronico no puede estar en blanco",
        "Contrasena es demasiado corta; minimo 6 caracteres",
        "Confirmar contrasena no coincide con Contrasena"
      )

      create(:user, email: "taken@example.com")
      invalid_user = User.new(email: "not-an-email", password: "password123", password_confirmation: "password123")
      duplicate_user = User.new(email: "taken@example.com", password: "password123", password_confirmation: "password123")

      invalid_user.valid?
      duplicate_user.valid?

      expect(invalid_user.errors.full_messages).to include("Correo electronico no es valido")
      expect(duplicate_user.errors.full_messages).to include("Correo electronico ya esta en uso")
    end
  end
end
