class AddFieldsToVernaculars < ActiveRecord::Migration[4.2]
  def change
    add_column(:vernaculars, :node_resource_pk, :string, index: true)
    add_column(:vernaculars, :locality, :string)
    add_column(:vernaculars, :remarks, :text)
    add_column(:vernaculars, :source, :text)
    add_column(:vernaculars, :resource_id, :integer)
  end
end
