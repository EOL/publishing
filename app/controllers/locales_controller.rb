class LocalesController < ApplicationController
  def set_locale
    locale_param = params.require(:set_locale)&.to_sym
    locale = locale_param == I18n.default_locale ? nil : locale_param
    referrer = request.referrer

    if referrer
      begin
        parsed_ref = URI::parse(referrer)
        url_options = Rack::Utils.parse_query(parsed_ref.query)
        url_options.merge!(Rails.application.routes.recognize_path(referrer))
        url_options[:locale] = locale
        url_options[:only_path] = true
        redirect_path = url_for(url_options)
      rescue ActionController::RoutingError
        redirect_path = nil
      end
    else
      redirect_path = nil
    end

    redirect_path = home_path(locale: locale) if redirect_path.blank?
    redirect_to redirect_path
  end
end
