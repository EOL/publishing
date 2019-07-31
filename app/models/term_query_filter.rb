class TermQueryFilter < ActiveRecord::Base
  belongs_to :term_query, :inverse_of => :filters
  validates_presence_of :term_query
  validate :validation

  # TODO: remove op field from db
  enum :op => {
    :is_any => 0,
    :is_obj => 1,
    :eq => 2,
    :gt => 3,
    :lt => 4,
    :range => 5
  }

  def inverse_pred_uri
    Eol::Uris.inverse(pred_uri)
  end

  def predicate?
    !pred_uri.blank?
  end

  def units_for_pred?
    pred_uri && !TraitBank::Terms.units_for_pred(pred_uri).nil?
  end

  def object_term?
    obj_uri.present?
  end

  def sex_term?
    sex_uri.present?
  end

  def life_stage_term?
    life_stage_uri.present?
  end

  def statistical_method_term?
    statistical_method_uri.present?
  end

  def meta?
    sex_term? || life_stage_term? || statistical_method_term?
  end

  def numeric?
    !num_val1.blank? || !num_val2.blank?
  end

  def gt?
    !num_val1.blank? && num_val2.blank?
  end

  def lt?
    num_val1.blank? && !num_val2.blank?
  end

  def eq?
    !num_val1.blank? && num_val1 == num_val2
  end

  def range?
    !num_val1.blank? && !num_val2.blank? && num_val1 != num_val2
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

  def to_cache_key
    pieces = []
    pieces << "op_#{op}"
    pieces << "pred_uri_#{pred_uri}"
    pieces << "obj_uri_#{obj_uri}" unless obj_uri.blank?
    pieces << "units_uri_#{units_uri}'" unless units_uri.blank?
    pieces << "num_val1_#{num_val1}" unless num_val1.blank?
    pieces << "num_val1_#{num_val2}" unless num_val2.blank?
    pieces << "sex_uri_#{sex_uri}" unless sex_uri.blank?
    pieces << "life_stage_uri_#{life_stage_uri}" unless life_stage_uri.blank?
    pieces << "statistical_method_uri_#{statistical_method_uri}" unless statistical_method_uri.blank?
    pieces.join('/')
  end

  def gt_val
    num_val1
  end

  def lt_val
    num_val2
  end

  def to_params
    {
      pred_uri: pred_uri,
      obj_uri: obj_uri,
      num_val1: num_val1,
      num_val2: num_val2,
      units_uri: units_uri
    }
  end

  def blank?
    pred_uri.blank? && obj_uri.blank?
  end

  private
  def validation
    if blank?
      errors.add(:pred_uri, "must specify an attribute or a value") 
      errors.add(:obj_uri, "must specify an attribute or a value") 
    elsif numeric?
      if pred_uri.blank?
        errors.add(:pred_uri, "can't be blank with a numeric value")
      elsif range? && num_val1 > num_val2
        errors.add(:num_val2, "must be >= to first value")
      end
    end
  end
end

