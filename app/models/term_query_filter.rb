class TermQueryFilter < ActiveRecord::Base
  belongs_to :term_query
  validates_presence_of :term_query
  validates_presence_of :filter_type
  validates_presence_of :pred_uri
  validates_presence_of :obj_uri, :if => :object_term?
  validates_presence_of :num_op, :if => :numeric?
  validates_presence_of :num_val1, :if => Proc.new { |o| o.numeric? || o.range? }
  validates_presence_of :num_val2, :if => :range?
  validate :fields_for_type

  enum :filter_type => {
    :predicate => 0,
    :object_term => 1,
    :numeric => 2,
    :range => 3
  }

  enum :num_op => {
    :eq => 0,
    :gt => 1,
    :lt => 2
  }

  private
    def fields_for_type
    end
end
