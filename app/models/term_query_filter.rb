class TermQueryFilter < ActiveRecord::Base
  belongs_to :term_query, :inverse_of => :filters
  belongs_to :resource
  validates_presence_of :term_query
  validate :validation

  attr_reader :show_extra_fields

  TermSelect = Struct.new(:type, :parent_uri, :selected_uri) do
    def persisted?
      false
    end

    def top_level?
      parent_uri.blank?
    end

    def terms
      @terms ||= top_level? ?
        TraitBank::Terms.top_level(type) :
        TraitBank::Terms.children(parent_uri)
    end
  end

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

  def lifestage_term?
    lifestage_uri.present?
  end

  def statistical_method_term?
    statistical_method_uri.present?
  end

  def extra_fields?
    sex_term? || 
    lifestage_term? || 
    statistical_method_term? ||
    resource
  end

  def show_extra_fields?
    show_extra_fields || extra_fields?
  end

  def clear_extra_fields
    self.sex_uri = nil
    self.lifestage_uri = nil
    self.statistical_method_uri = nil
    self.resource = nil
    self.show_extra_fields = false
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
    pieces << "sex_uri:#{sex_uri}" unless sex_uri.blank?
    pieces << "lifestage_uri:#{lifestage_uri}" unless lifestage_uri.blank?
    pieces << "statistical_method_uri:#{statistical_method_uri}" unless statistical_method_uri.blank?
    pieces << "resource_id:#{resource.id}" unless resource.blank?
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
    pieces << "lifestage_uri_#{lifestage_uri}" unless lifestage_uri.blank?
    pieces << "statistical_method_uri_#{statistical_method_uri}" unless statistical_method_uri.blank?
    pieces << "resource_id_#{resource.id}" unless resource.blank?
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
      units_uri: units_uri,
      sex_uri: sex_uri,
      lifestage_uri: lifestage_uri,
      statistical_method_uri: statistical_method_uri,
      resource_id: resource&.id
    }
  end

  def blank?
    pred_uri.blank? && obj_uri.blank?
  end

  def really_blank?
    blank? &&
    sex_uri.blank? &&
    lifestage_uri.blank? &&
    statistical_method_uri.blank? &&
    resource.blank?
  end

  def show_extra_fields=(val)
    @show_extra_fields = ActiveRecord::Type::Boolean.new.type_cast_from_user(val)
  end

  def pred_term_selects
    @pred_term_selects ||= [TermSelect.new(:predicate, nil, nil)]
  end

  def obj_term_selects
    @obj_term_selects ||= [TermSelect.new(:object_term, nil, nil)]
  end

  def pred_term_selects_attributes=(attrs)
    selects = []
    
    sorted_keys = attrs.keys.sort
    attr_arr = sorted_keys.collect { |k| attrs[k] }
    with_uri = attr_arr.select { |attr| attr[:selected_uri].present? }
    last_with_uri = with_uri.any? ? with_uri.last : nil

    if last_with_uri && last_with_uri[:selected_uri] != pred_uri
      @pred_term_selects = [TermSelect.new(:predicate, nil, nil)]
      return
    end

    i = 0
    continue = true

    while i < attr_arr.length && continue
      field = attr_arr[i]
      if i == 0 || field[:parent_uri] == selects[i - 1].selected_uri
        selects << TermSelect.new(field[:type].to_sym, field[:parent_uri], field[:selected_uri])
        added = true
      else 
        added = false
      end

      continue = added && field[:selected_uri].present?
      i += 1
    end
        
    if selects.last.selected_uri.present?
      child_select = TermSelect.new(
        selects.last.type, 
        selects.last.selected_uri,
        nil
      )
      selects << child_select if child_select.terms.any?
    end

    @pred_term_selects = selects
  end
  
  def obj_term_selects_attributes=(attrs)
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

