class ChangeTextLimits < ActiveRecord::Migration[4.2]
  def up
    change_column :articles, :body, :text, null: false, limit: 4.gigabytes - 1,
      comment: "html; run through namelinks; was description_linked"
  end

  def down
    change_column :articles, :body, :text, null: false, limit: 64.kilobytes - 1,
      comment: "html; run through namelinks; was description_linked"
  end
end
