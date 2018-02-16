class TermQueryRangeFilter < ActiveRecord::Base
  belongs_to :term_query
  validates_presence_of :term_query
  validates_presence_of :from_value
  validates_presence_of :to_value
  validates_presence_of :units_uri
  validates_presence_of :pred_uri
end
