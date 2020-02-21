class CreateSearchSuggestions < ActiveRecord::Migration[4.2]
  def change
    create_table :search_suggestions do |t|
      t.integer :page_id, comment: "a species or clade page ID"
      t.integer :synonym_of_id,
        comment: "Use the values from another search suggestion"
      # NOTE: you would think we would index the match, but we are going to use
      # Solr to manage that. No need:
      t.string :match, null: false,
        comment: "this is the string that we will match from the search query; CASE INSENSITIVE"
      t.string :object_term,
        comment: "will start a Trait search for this particular URI as an object term"
      t.string :path,
        comment: "When you want to direct them to a content URL; use RELATIVE paths (e.g.: /content/foo, not eol.org/content/foo)"
      t.text :wkt_string,
        comment: "A bounding box for geographic terms, used to narrow search results by location. Should probably start with 'POLYGON' and should be URI-escaped."
    end
  end
end
