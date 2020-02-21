class ChangeHomePageFeedFieldsNameToFieldMask < ActiveRecord::Migration[4.2]
  def change
    rename_column :home_page_feeds, :fields, :field_mask
  end
end
