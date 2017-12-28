class TermQueryPair < ActiveRecord::Base
  belongs_to :term_query, :inverse_of => :pairs

  validates_presence_of :predicate
  validates_presence_of :term_query

  def initialize(*)
    super
    self.predicate = nil if predicate.blank?
    self.object = nil if object.blank?
  end
end
