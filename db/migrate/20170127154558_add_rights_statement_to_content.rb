class AddRightsStatementToContent < ActiveRecord::Migration
  def change
    add_column :media, :rights_statement, :string
    add_column :articles, :rights_statement, :string
    add_column :links, :rights_statement, :string
    # NOTE: this is not adding a rights statement, but it was needed:
    add_column :attributions, :url, :string
  end
end
