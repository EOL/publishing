# 20220502095700
class AddNativeToResources < ActiveRecord::Migration[5.2]
  def up
    add_column :resources, :native, :boolean, default: false, null: false
    resource =
      Resource.where(abbr: 'dvdtg').first_or_create do |r|
        r.name = 'EOL Dynamic Hierarchy 1.1'
        r.partner = Partner.native
        r.description = ''
        r.abbr = 'dvdtg'
        r.is_browsable = true
        r.has_duplicate_nodes = false
        r.nodes_count = 650000
      end
    resource.update_attribute(:native, true)
  end

  def down
    remove_column :resources, :native
  end
end
