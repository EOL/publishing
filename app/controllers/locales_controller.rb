class LocalesController < ApplicationController
  def set_locale
    locale = params.require(:set_locale)

    referrer = request.referrer
    if referrer
      begin
        url_options = Rails.application.routes.recognize_path(referrer)
      rescue ActionController::RoutingError
        url_options = nil  
      end
    else
      url_options = nil
    end

    redirect_path = if url_options 
                      url_options[:locale] = locale.to_sym == I18n.default_locale ?
                        nil :
                        locale

                      url_options[:only_path] = true
                      url_for(url_options)
                    else
                      home_path :locale => locale
                    end
    redirect_to redirect_path
  end
end
