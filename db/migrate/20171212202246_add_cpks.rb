class AddCpks < ActiveRecord::Migration[4.2]
  def change
    {
      collections_users: %i[user_id collection_id],
      pages_referents: %i[page_id referent_id],
      partners_users: %i[partner_id user_id],
      references: %i[parent_type parent_id referent_id],
      articles_collected_pages: %i[collected_page_id article_id],
      collected_pages_links: %i[collected_page_id link_id],
      collected_pages_media: %i[collected_page_id medium_id]
    }.each do |table, keys|
      execute("ALTER TABLE `#{table}` ADD PRIMARY KEY (#{keys.join(', ')});")
    end
  end
end
