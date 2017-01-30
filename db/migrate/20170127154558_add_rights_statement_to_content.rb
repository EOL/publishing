class AddRightsStatementToContent < ActiveRecord::Migration
  def change
    add_column :media, :rights_statement, :string, limit: 1024
    add_column :articles, :rights_statement, :string, limit: 1024
    add_column :links, :rights_statement, :string, limit: 1024
    # NOTE: this is not adding a rights statement, but it was needed:
    add_column :attributions, :url, :string, limit: 512
  end
end
