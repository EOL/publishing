class ForceCreateTraitEolPkConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :Trait, :eol_pk, force: true
  end

  def down
    drop_constraint :Trait, :eol_pk
  end
end
