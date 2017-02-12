class Node < ActiveRecord::Base
  include Names
  
  belongs_to :page, inverse_of: :nodes
  belongs_to :resource, inverse_of: :nodes
  belongs_to :rank

  has_many :vernaculars, inverse_of: :node
  has_one :taxon_remark, inverse_of: :node

  # TODO: do we need these with acts_as_nested_set?
  has_many :scientific_names, inverse_of: :node

  
  
  acts_as_nested_set scope: :resource, counter_cache: :children_count

  counter_culture :resource
end
