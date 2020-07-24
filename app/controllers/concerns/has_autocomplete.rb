module HasAutocomplete
  extend ActiveSupport::Concern

  def autocomplete_results(sk_result, controller)
    result_hash = {}

    sk_result.response["suggest"]["autocomplete"].first["options"].each do |r|
      text = r["text"]
      id = r["_id"]

      if result_hash.key?(text)
        name = params[:no_multiple_text] ? text : "#{text} (multiple hits)"
        url = search_path(q: text, utf8: true)
      else
        name = text
        url = url_for(controller: controller, action: "show", id: id)
      end

      result_hash[text] = { 
        name: name, 
        title: name, 
        id: id, 
        url: url
      }
    end

    result_hash.values
  end
end
