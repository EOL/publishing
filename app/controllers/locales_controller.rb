class LocalesController < ApplicationController

  def set_locale
    locale_param = params.require(:set_locale)&.to_sym
    I18n.locale = locale_param # this is needed by the refinery business
    locale = locale_param == I18n.default_locale ? nil : locale_param
    referrer = request.referrer

    if referrer
        refinery_match = referrer.match(REFINERY_PATTERN)

        if refinery_match
          path = refinery_match.captures
          redirect_path = refinery.marketable_page_path(path, locale: locale)
        else
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
        end
    else
      redirect_path = nil
    end

    redirect_path = home_path(locale: locale) if redirect_path.blank?
    redirect_to redirect_path
  end

  private
  def self.locale_pattern_part
    str = I18n.available_locales.reject { |l| l == I18n.default_locale}.join('|')
    "(?:(?:#{str})\/)?"
  end
  REFINERY_PATTERN = /\/#{self.locale_pattern_part}#{Refinery::Core.config.mounted_path.gsub("/", "")}\/#{self.locale_pattern_part}((?!cms(?:$|\/)).*)/
end
