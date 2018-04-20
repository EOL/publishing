class TermQueryFilter < ActiveRecord::Base
  belongs_to :term_query, :inverse_of => :filters
  validates_presence_of :term_query
  validates_presence_of :pred_uri
  validates_presence_of :op
  validates_presence_of :obj_uri, :if => :object_term?
  validates_presence_of :units_uri, :if => :numeric?
  validates :num_val1, :presence => true, :numericality => true, :if => :numeric_or_range?
  validates :num_val2, :presence => true, :numericality => true, :if => :range?

  enum :op => {
    :is_any => 0,
    :is_obj => 1,
    :eq => 2,
    :gt => 3,
    :lt => 4,
    :range => 5
  }

  def predicate?
    is_any?
  end

  def object_term?
    is_obj?
  end

  def numeric?
    eq? || gt? || lt?
  end

  def valid_ops
    ops = [:is_any]

    if pred_uri
      ops << :is_obj if TraitBank::Terms.any_obj_terms_for_pred?(pred_uri)
      ops += [
        :eq,
        :lt,
        :gt,
        :range
      ] if TraitBank::Terms.units_for_pred(pred_uri)
    end

    ops
  end

  def to_s
    pieces = []
    pieces << "op: :#{op}"
    pieces << "pred_uri:'#{pred_uri}'"
    pieces << "obj_uri:'#{obj_uri}'" unless obj_uri.blank?
    pieces << "units_uri:'#{units_uri}'" unless units_uri.blank?
    pieces << "num_val1:#{num_val1}" unless num_val1.blank?
    pieces << "num_val1:#{num_val2}" unless num_val2.blank?
    "{#{pieces.join(',')}}"
  end

  private
  def numeric_or_range?
    numeric? || range?
  end
end
