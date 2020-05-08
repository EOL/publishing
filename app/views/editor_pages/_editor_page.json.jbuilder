json.extract! editor_page, :id, :title, :slug, :content, :created_at, :updated_at
json.url editor_page_url(editor_page, format: :json)
