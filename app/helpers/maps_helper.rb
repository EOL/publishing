module MapsHelper
  def map_json_path(page)
    if page.occurrence_map?
      prefix = page.id.to_i % 100
      asset_path("/data/map_data_dwca/#{prefix}/#{page.id}.json")
    else
      nil
    end
  end
end
