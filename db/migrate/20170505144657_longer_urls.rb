class LongerUrls < ActiveRecord::Migration[4.2]
  def change
    # IE has a limit of 2,083 characters (which is weird). Others can have
    # different limits, but this seems reasonable as a benchmark. I'll double
    # that to be safe. I AM NOT INCREASING *ALL* URLs. ...Most URLs will NOT
    # have querystrings in them and don't need the extra length. I'm only
    # adjusting where it's feasible to have querystrings.
    max_url_size = 4096
    change_column :nodes, :source_url, :string, limit: max_url_size
    change_column :media, :source_url, :string, limit: max_url_size
    change_column :media, :source_page_url, :string, limit: max_url_size
    change_column :articles, :source_url, :string, limit: max_url_size
    change_column :links, :source_url, :string, limit: max_url_size
    change_column :resources, :node_source_url_template, :string, limit: max_url_size
    change_column :refinery_pages, :link_url, :string, limit: max_url_size
  end
end
