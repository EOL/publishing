class TermQueryObjectTermFilter < ActiveRecord::Base
  belongs_to :term_query
  validates_presence_of :term_query
  validates_presence_of :uri
  validates_presence_of :pred_uri
end
