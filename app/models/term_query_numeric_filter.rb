class TermQueryNumericFilter < ActiveRecord::Base
  belongs_to :term_query
  validates_presence_of :term_query
  validates_presence_of :value
  validates_presence_of :op
  validates_presence_of :units_uri
  validates_presence_of :pred_uri

  enum :op => {
    :eq => 0,
    :gt => 1,
    :lt => 2
  }
end
