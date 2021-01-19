class ResourceNode
  include ActiveGraph::Node

  self.mapped_label_name = 'Resource'

  id_property :resource_id

  has_one :in, :trait, type: :supplier, model_class: :Trait

  def resource
    Resource.find(id)
  end
end
