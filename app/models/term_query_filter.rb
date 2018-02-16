class TermQueryFilter < ActiveRecord::Base
  belongs_to :term_query
  belongs_to :object, :polymorphic => true
  validates_presence_of :object
  validates_presence_of :term_query
  validates_presence_of :pred_uri
end
