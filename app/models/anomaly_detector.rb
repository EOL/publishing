# looks for ... strange artifacts in the DB. Fixes them where possible, reports on others.
class AnomalyDetector
  # TODO: ScientificName where the Node it's attached to is a) missing b) not in the same resource. Not sure what caused
  # this. :|
  def bad_nodes_on_scientific_names
    ScientificName.joins(:node).where('scientific_names.resource_id != nodes.resource_id').count
    # TODO: remove that resoource_id ...I am testing.
    ScientificName.where(resource_id: 452).includes(:node).where( node: { id: nil } ).count

  end
end
