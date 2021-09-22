module Autocomplete
  extend ActiveSupport::Concern

  DEFAULT_AUTOCOMPLETE_LIMIT = 10 
  I18N_ENABLED = Rails.configuration.x.autocomplete_i18n_enabled

  class_methods do
    def autocompletes(field_name)
      @ac_field_name = field_name
    end

    def autocomplete_field_name
      "#{@ac_field_name}_#{I18n.locale}"
    end

    def autocomplete(query, options = {})
      self.assert_autocompletes
      locale = options[:locale] || I18n.locale

      begin 
        search body: {
          suggest: {
            autocomplete: { # arbitrary name, but expected by SearchController
              prefix: query,
              completion: {
                field: "#{@ac_field_name}_#{locale}",
                size: options[:limit] || DEFAULT_AUTOCOMPLETE_LIMIT
              }
            }
          }
        }
      rescue Searchkick::InvalidQueryError => e
        raise e if locale == I18n.default_locale

        logger.warn("Error in autocomplete, possibly due to locale #{locale} missing from index. Retrying with default locale.")
        return autocomplete(query, options.merge(locale: I18n.default_locale))
      end
    end

    def autocomplete_searchkick_properties
      self.assert_autocompletes
      I18n.available_locales.collect do |locale|
        [:"#{@ac_field_name}_#{locale}", { type: "completion" }]
      end.to_h
    end

    def assert_autocompletes
      raise "you must call autocompletes(<field_name>) from the including class before calling this method" unless @ac_field_name
    end
  end
end
