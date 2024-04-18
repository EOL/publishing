class ForceCreateMetaDataEolPkConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :MetaData, :eol_pk, force: true
  end

  def down
    drop_constraint :MetaData, :eol_pk
  end
end
