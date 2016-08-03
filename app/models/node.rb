class Node < ActiveRecord::Base
  belongs_to :page, inverse_of: :nodes
  belongs_to :resource, inverse_of: :nodes
  belongs_to :rank

  has_one :taxon_remark, inverse_of: :node

  # TODO: do we need these with acts_as_nested_set?
  has_many :node_ancestors, inverse_of: :node
  has_many :scientific_names, inverse_of: :node
  has_many :vernaculars, inverse_of: :node

  acts_as_nested_set scope: :resource, counter_cache: true

  counter_culture :resource
end
