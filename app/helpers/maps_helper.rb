module MapsHelper
  def maps_json_path(page)
    if page.occurrence_map?
      prefix = page.id.to_i % 100
      "/maps/#{prefix}/#{page.id}.json"
    else
      nil
    end
  end
end
