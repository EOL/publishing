class TermQueryFilter < ApplicationRecord
  belongs_to :term_query, :inverse_of => :filters
  belongs_to :resource, optional: true
  belongs_to :object_clade, class_name: "Page", optional: true
  validates_presence_of :term_query
  validate :validation

  attr_reader :show_extra_fields
  attr_accessor :top_pred_uri

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

  Term = Struct.new(:uri, :type)

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

  def pred_node
    if pred_uri
      @pred_node ||= TermNode.find(pred_uri)
    else
      nil
    end
  end

  def units_for_pred?
    pred_uri && !TraitBank::Terms.units_for_pred(pred_uri).nil?
  end

  def association_pred?
    pred_node&.type == "association"
  end

  def object_term?
    obj_uri.present?
  end

  def object?
    object_term? || object_clade.present?
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
    @show_extra_fields = ActiveRecord::Type::Boolean.new.cast(val)
  end

  def pred_term_selects
    if @pred_term_selects.nil?
      self.pred_term_selects_attributes = {}
    end

    @pred_term_selects
  end

  def obj_term_selects
    @obj_term_selects ||= [TermSelect.new(:object_term, nil, nil)]
  end

  def pred_term_selects_attributes=(attrs)
    selects = []

    if top_pred_uri.present?
      sorted_keys = attrs.keys.sort
      attr_arr = sorted_keys.collect { |k| attrs[k] }

      if attr_arr.any? && top_pred_uri == attr_arr.first[:parent_uri]
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
      end

      if selects.empty? || selects.last.selected_uri.present?
        if selects.empty?
          parent_uri = pred_uri
        else
          parent_uri = selects.last.selected_uri
        end

        child_select = TermSelect.new(
          :predicate,
          parent_uri,
          nil
        )

        selects << child_select if child_select.terms.any?
      end
    end

    @pred_term_selects = selects
  end

  def obj_term_selects_attributes=(attrs)
  end

  def pred_term_node
    return @pred_term_node if @pred_term_node
    @pred_term_node = predicate? ? TermNode.find(pred_uri) : nil
  end

  def obj_term_node
    return @obj_term_node if @obj_term_node
    @obj_term_node = object_term? ? TermNode.find(obj_uri) : nil
  end

  def max_trait_row_count_term
    return @max_trait_row_count_term if @max_trait_row_count_term

    pred_count = pred_term_node&.trait_row_count || 0
    obj_count = obj_term_node&.trait_row_count || 0
    
    @max_trait_row_count_term = if pred_count > obj_count
                                  Term.new(pred_uri, :predicate)
                                else
                                  Term.new(obj_uri, :object_term)
                                end
  end

  def min_distinct_page_count
    [pred_term_node, obj_term_node].compact.map { |t| t.distinct_page_count }.min || 0
  end

  def object_term
    if object_term?
      Term.new(obj_uri, :object_term)
    else
      nil
    end
  end

  def predicate_term
    if predicate?
      Term.new(pred_uri, :predicate)
    else
      nil
    end
  end

  private
  def validation
    if blank?
      errors.add(:pred_uri, I18n.t("term_query_filter.validations.blank_error"))
      errors.add(:obj_uri, I18n.t("term_query_filter.validations.blank_error"))
    else
      validate_terms_exist

      if numeric?
        if pred_uri.blank?
          errors.add(:pred_uri, I18n.t("term_query_filter.validations.pred_uri_blank_numeric_error"))
        elsif range? && num_val1 > num_val2
          errors.add(:num_val2, I18n.t("term_query_filter.validations.range_invalid_error"))
        end
      end
    end
  end

  # XXX: update this method with any added term uri attributes
  def validate_terms_exist
    %i(pred_uri obj_uri units_uri sex_uri lifestage_uri statistical_method_uri).each do |uri_method|
      uri = send(uri_method)

      if uri.present?
        record = TraitBank.term_record(uri) 
        errors.add(uri_method, I18n.t("term_query_filter.validations.invalid_uri")) if record.nil?
      end
    end
  end
end
