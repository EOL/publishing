module TermQueryFilter extend ActiveSupport::Concern
  included do
    belongs_to :term_query
    validates_presence_of :term_query
    validates_presence_of :pred_uri
  end
end
