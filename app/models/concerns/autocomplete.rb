module Autocomplete
  extend ActiveSupport::Concern

  DEFAULT_AUTOCOMPLETE_LIMIT = 10 

  class_methods do
    def autocompletes(field_name)
      @ac_field_name = field_name
    end

    def autocomplete(query, options = {})
      raise "you must call autocompletes(<field_name>) from the including class before calling this method" unless @ac_field_name
      search body: {
        suggest: {
          autocomplete: { # arbitrary name, but expected by SearchController
            prefix: query,
            completion: {
              field: @ac_field_name,
              size: options[:limit] || DEFAULT_AUTOCOMPLETE_LIMIT
            }
          }
        }
      }
    end
  end
end
