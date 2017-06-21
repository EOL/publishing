# NOTE: to create one of these manually, you need to do something like one of:
#
# raccoon = SearchSuggestion.create(match: "raccoon", page_id: 1234)
# SearchSuggestion.create(match: "common raccoon", synonym_of: raccoon)
# SearchSuggestion.create(match: "taiga", object_term: "http://eol.org/schema/terms/boreal_forests_taiga")
# SearchSuggestion.create(match: "about", path: "/cms/about_us")
# SearchSuggestion.create(match: "boston", wkt_string: "POLYGON%20%28%28-72.147216796875%2041.492120839687786%2C%20-72.147216796875%2043.11702412135048%2C%20-69.949951171875%2043.11702412135048%2C%20-69.949951171875%2041.492120839687786%2C%20-72.147216796875%2041.492120839687786%29%29")
class SearchSuggestion < ActiveRecord::Base
  belongs_to :page
  belongs_to :synonym_of, class_name: "SearchSuggestion"

  validates :match, uniqueness: true

  searchable do
    text :match, boost: 10.0 do
      match.gsub(/\s/, " ")
    end
  end
end
