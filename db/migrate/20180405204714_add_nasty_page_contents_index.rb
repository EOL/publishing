class AddNastyPageContentsIndex < ActiveRecord::Migration[4.2]
  def change
      # PageContent Load (2570.0ms)  SELECT  `page_contents`.* FROM `page_contents` WHERE `page_contents`.`page_id` =
      # 694 AND `page_contents`.`is_hidden` = 0 AND (`page_contents`.`trust` != 2) AND `page_contents`.`content_type` =
      # 'Medium'  ORDER BY `page_contents`.`position` ASC LIMIT 30 OFFSET 0
    add_index :page_contents, [:page_id, :content_type, :position], name: :contents_for_page_index
  end
end
