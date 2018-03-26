json.extract! home_page_feed, :id, :name, :fields, :created_at, :updated_at
json.url home_page_feed_url(home_page_feed, format: :json)
