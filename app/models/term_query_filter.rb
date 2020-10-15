class TermQueryFilter < ApplicationRecord
  belongs_to :term_query, :inverse_of => :filters
  belongs_to :resource, optional: true
  belongs_to :obj_clade, class_name: "Page", optional: true

  include RecordBelongsToNode
  belongs_to_node :predicate, "TermNode"
  belongs_to_node :object_term, "TermNode"
  belongs_to_node :units_term, "TermNode"
  belongs_to_node :sex_term, "TermNode"
  belongs_to_node :lifestage_term, "TermNode"
  belongs_to_node :statistical_method_term, "TermNode"
  
  validates_presence_of :term_query
  validate :validation

  attr_reader :show_extra_fields, :root_predicate_id

  class TermSelect
    attr_reader :type, :parent_term, :selected_term

    def initialize(type, parent_term_id, selected_term_id)
      @type = type
      @parent_term = TermNode.find(parent_term_id)
      @selected_term = selected_term_id.present? ? TermNode.find(selected_term_id) : nil
    end

    def persisted?
      false
    end

    def top_level?
      parent_term.nil?
    end

    def terms
      @terms ||= parent_term.children
    end

    def selected_term_id
      selected_term&.id
    end

    def parent_term_id
      parent_term.id
    end
  end

  Field = Struct.new(:value, :trait_row_count, :type)

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
    predicate_id.present?
  end

  def units_for_predicate?
    predicate? && predicate.units_term.present?
  end

  def predicate_has_numeric_value?
    predicate? && predicate.numeric_value_predicate?
  end

  def predicate_units_term
    predicate&.units_term
  end


  def association_pred?
    predicate&.type == "association"
  end

  def object_term?
    object_term.present?
  end

  def object?
    object_term? || obj_clade.present?
  end

  def units_term?
    units_term.present?
  end

  def sex_term?
    sex_term.present?
  end

  def lifestage_term?
    lifestage_term.present?
  end

  def statistical_method_term?
    statistical_method_term.present?
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
    self.sex_term_id = nil
    self.lifestage_term_id = nil
    self.statistical_method_term_id = nil
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
    pieces << "predicate_uri:'#{predicate.uri}'" unless predicate.nil?
    pieces << "obj_uri:'#{object_term.uri}'" unless object_term.nil?
    pieces << "obj_clade_id:'#{obj_clade_id}'" unless obj_clade_id.blank?
    pieces << "units_uri:'#{units_term.uri}'" unless units_term.nil?
    pieces << "num_val1:#{num_val1}" unless num_val1.blank?
    pieces << "num_val1:#{num_val2}" unless num_val2.blank?
    pieces << "sex_uri:#{sex_term.uri}" unless sex_term.nil?
    pieces << "lifestage_uri:#{lifestage_term.uri}" unless lifestage_term.nil?
    pieces << "statistical_method_uri:#{statistical_method_term.uri}" unless statistical_method_term.nil?
    pieces << "resource_id:#{resource.id}" unless resource.blank?
    "{#{pieces.join(',')}}"
  end

  def to_cache_key
    pieces = []
    pieces << "op_#{op}"
    pieces << "predicate_id_#{predicate_id}"
    pieces << "object_term_id_#{object_term_id}" unless object_term_id.blank?
    pieces << "obj_clade_id_#{obj_clade_id}" unless obj_clade_id.blank?
    pieces << "units_term_id_#{units_term_id}'" unless units_term_id.blank?
    pieces << "num_val1_#{num_val1}" unless num_val1.blank?
    pieces << "num_val1_#{num_val2}" unless num_val2.blank?
    pieces << "sex_term_id_#{sex_term_id}" unless sex_term_id.blank?
    pieces << "lifestage_term_id_#{lifestage_term_id}" unless lifestage_term_id.blank?
    pieces << "statistical_method_term_id_#{statistical_method_term_id}" unless statistical_method_term_id.blank?
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
      predicate_id: predicate_id,
      object_term_id: object_term_id,
      num_val1: num_val1,
      num_val2: num_val2,
      units_term_id: units_term_id,
      sex_term_id: sex_term_id,
      lifestage_term_id: lifestage_term_id,
      statistical_method_term_id: statistical_method_term_id,
      resource_id: resource_id
    }
  end

  def blank?
    predicate_id.blank? && object_term_id.blank? && obj_clade.nil?
  end

  def extra_fields_blank?
    sex_term_id.blank? &&
    lifestage_term_id.blank? &&
    statistical_method_term_id.blank? &&
    resource.blank?
  end
    
  def really_blank?
    blank? && extra_fields_blank?
  end

  def object_term_only?
    predicate_id.blank? && obj_clade.nil? && extra_fields_blank?
  end

  def show_extra_fields=(val)
    @show_extra_fields = ActiveRecord::Type::Boolean.new.cast(val)
  end

  def predicate_child_selects
    if @predicate_child_selects.nil?
      self.predicate_child_selects_attributes = {}
    end

    @predicate_child_selects
  end

  def object_term_selects
    @object_term_selects ||= [TermSelect.new(:object_term, nil, nil)]
  end

  def predicate_child_selects_attributes=(attrs)
    selects = []

    if root_predicate.present?
      sorted_keys = attrs.keys.sort
      attr_arr = sorted_keys.collect { |k| attrs[k] }

      if attr_arr.any? && root_predicate.id == attr_arr.first[:parent_term_id].to_i
        i = 0
        continue = true

        while i < attr_arr.length && continue
          field = attr_arr[i]
          selected_id = field[:selected_term_id].blank? ? nil : Integer(field[:selected_term_id])
          parent_id = field[:parent_term_id].blank? ? nil : Integer(field[:parent_term_id])

          if i == 0 || parent_id == selects[i - 1].selected_term.id
            selects << TermSelect.new(field[:type].to_sym, parent_id, selected_id)
            added = true
          else
            added = false
          end

          continue = added && selected_id
          i += 1
        end
      end

      if selects.empty? || selects.last.selected_term.present?
        if selects.empty?
          parent_id = root_predicate.id
        else
          parent_id = selects.last.selected_term.id
        end

        child_select = TermSelect.new(
          :predicate,
          parent_id,
          nil
        )

        selects << child_select if child_select.terms.any?
      end
    end

    @predicate_child_selects = selects
  end

  def obj_term_selects_attributes=(attrs)
  end

  def object_clade_node
    return @obj_clade_node if @obj_clade_node
    @obj_clade_node = obj_clade_id.present? ? PageNode.find(obj_clade_id) : nil
  end

  # TODO: fix/update
  def all_fields
    [pred_field, obj_term_field, obj_clade_field].compact
  end

  def max_trait_row_count_fields
    return @max_trait_row_count_fields if @max_trait_row_count_fields

    @max_trait_row_count_fields = all_fields.max(all_fields.length - 1) do |a, b|
      a.trait_row_count <=> b.trait_row_count
    end
  end

  def min_distinct_page_count
    [predicate, object_term].compact.map { |t| t.distinct_page_count }.min || 0
  end

  def obj_clade_field
    obj_clade_id.present? ? Field.new(obj_clade_id, obj_clade_node.obj_trait_count, :object_clade) : nil
  end 

  def obj_term_field
    if object_term?
      Field.new(object_term.uri, object_term.trait_row_count, :object_term)
    else
      nil
    end
  end

  def pred_field
    if predicate?
      Field.new(predicate.uri, predicate.trait_row_count, :predicate)
    else
      nil
    end
  end

  def root_predicate_id=(val)
    @root_predicate_id = val.blank? ? nil : Integer(val) # might get passed strings from params
  end

  def root_predicate
    return nil if root_predicate_id.blank?
    @root_predicate ||= TermNode.find(root_predicate_id)
  end

  private
  def validation
    if blank?
      errors.add(:predicate_id, I18n.t("term_query_filter.validations.blank_error"))
      errors.add(:object_term_id, I18n.t("term_query_filter.validations.blank_error"))
      errors.add(:obj, I18n.t("term_query_filter.validations.blank_error"))
    elsif obj_clade.present? 
      if predicate_id.blank?
        errors.add(:predicate_id, I18n.t("pred_uri_blank_obj_clade_error"))
      elsif obj_uri.present?
        errors.add(:obj_clade_id, I18n.t("term_query_filter.validations.multi_obj_error"))
        errors.add(:object_term_id, I18n.t("term_query_filter.validations.multi_obj_error"))
      end
    else
      if numeric?
        if predicate_id.blank?
          errors.add(:predicate_id, I18n.t("term_query_filter.validations.pred_uri_blank_numeric_error"))
        elsif range? && num_val1 > num_val2
          errors.add(:num_val2, I18n.t("term_query_filter.validations.range_invalid_error"))
        end
      end
    end
  end
end

