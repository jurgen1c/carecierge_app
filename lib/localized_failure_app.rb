class LocalizedFailureApp < Devise::FailureApp
  protected

  def scope_url
    destination = super
    return destination if I18n.locale == I18n.default_locale

    uri = URI.parse(destination)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    uri.query = query.merge("locale" => I18n.locale.to_s).to_query
    uri.to_s
  end
end
