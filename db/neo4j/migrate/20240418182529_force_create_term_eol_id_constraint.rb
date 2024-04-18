class ForceCreateTermEolIdConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :Term, :eol_id, force: true
  end

  def down
    drop_constraint :Term, :eol_id
  end
end
