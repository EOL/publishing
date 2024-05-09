class ForceCreatePagePageIdConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :Page, :page_id, force: true
  end

  def down
    drop_constraint :Page, :page_id
  end
end
