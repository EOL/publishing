class TermNames::Dumper
  FILE_PATH = Rails.application.root.join("public", "data", "term_name_translations.json")

  class << self
    def dump
      by_domain = {}

      I18n.t("term.name.by_uri").each do |k, v|
        uri = k.to_s.gsub("(dot)", ".")
        start_part = /https?\:\/\/[^\/]*/.match(uri)&.[](0) || "#{uri} (unparseable)"
        vals_by_lang = {}

        I18n.available_locales.each do |locale|
          val = I18n.t("term.name.by_uri.#{k}", locale: locale, default: nil, fallback: false)
          if val
            vals_by_lang[locale] = val
          end
        end

        by_domain[start_part] ||= {}
        by_domain[start_part][uri] = vals_by_lang
      end

      Rails.logger.info("(over)writing file #{FILE_PATH}")
      File.open(FILE_PATH, "w") do |file|
        file.write(JSON.dump(by_domain))
      end
      Rails.logger.info("done")
    end
  end
end


