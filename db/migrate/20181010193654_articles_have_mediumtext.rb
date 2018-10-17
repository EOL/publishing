class ArticlesHaveMediumtext < ActiveRecord::Migration
  def change
    Article.connection.execute(%{
      ALTER TABLE articles CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `body` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `owner` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
      MODIFY `rights_statement` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
    })
  end
end
