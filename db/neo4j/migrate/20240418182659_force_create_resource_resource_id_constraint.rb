class ForceCreateResourceResourceIdConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :Resource, :resource_id, force: true
  end

  def down
    drop_constraint :Resource, :resource_id
  end
end
