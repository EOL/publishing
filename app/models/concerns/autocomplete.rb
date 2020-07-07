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
      search body: {
        suggest: {
          autocomplete: { # arbitrary name, but expected by SearchController
            prefix: query,
            completion: {
              field: "#{@ac_field_name}_#{I18n.locale}",
              size: options[:limit] || DEFAULT_AUTOCOMPLETE_LIMIT
            }
          }
        }
      }
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
