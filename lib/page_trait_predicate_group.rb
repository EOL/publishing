require 'set'

# Represents a predicate and page role for traits belonging to that predicate. Page role is defined as:
# :subject - if the page only has traits where (page)-[:trait|:inferred_trait]->(trait) belonging to the predicate
# :object - if the page only has traits where (trait)-[:object_page]->(page) belonging to the predicate
# :both - if the page has traits that belong to both cases
class PageTraitPredicateGroup
  VALID_TYPES = [:subject, :object, :both]

  attr_accessor :term, :type

  def initialize(term, type)
    raise TypeError, "term can't be nil" if term.nil?
    raise TypeError, "type #{type} invalid" unless VALID_TYPES.include?(type)

    @term = term
    @type = type
  end

  def term_id
    @term.id
  end

  def id
    "#{term_id}_#{@type}"
  end

  def uri
    @term.uri
  end

  def subject?
    include_type?(:subject)
  end

  def object?
    include_type?(:object)
  end

  def include_type?(type)
    @type == type || @type == :both
  end

  def name
    object? ? @term.i18n_inverse_name : @term.i18n_name
  end

  def ==(other)
    self.class === other and
      other.term.id == @term.id and
      other.type == @type
  end

  alias eql? ==

  def hash
    @term.id ^ @type.hash
  end

  def to_s
    "PageTraitPredicateGroup_#{id}"
  end

  class << self
    include TraitBank::Constants

    def grouped_traits_for_page(page, options = {})
      raise TypeError, "must include limit or selected_group option" unless options[:limit] || options[:selected_group]

      subj_trait_pks_by_group = subj_trait_pks_for_page(page.page_node, options)
      obj_trait_pks_by_group = obj_trait_pks_for_page(page.page_node, options)
      subj_trait_pks = extract_grouped_trait_pks(subj_trait_pks_by_group)
      subj_trait_pk_set = Set.new(subj_trait_pks)
      all_trait_pks = (
        subj_trait_pks +
        extract_grouped_trait_pks(obj_trait_pks_by_group)
      ).uniq

      all_traits = Trait.for_eol_pks(all_trait_pks).map do |t| 
        role = subj_trait_pk_set.include?(t.id) ? :subject : :object
        TraitWithPageRole.new(t, role)
      end

      all_traits_by_id = all_traits.map { |t| [t.id, t] }.to_h
      subj_traits_by_pred = build_traits_by_pred(subj_trait_pks_by_group, all_traits_by_id)
      obj_traits_by_pred = build_traits_by_pred(obj_trait_pks_by_group, all_traits_by_id)
      grouped_traits = {}

      subj_traits_by_pred.each do |pred, traits|
        group_type = :subject

        if pred.is_symmetrical_association
          obj_traits_for_pred = obj_traits_by_pred.delete(pred)

          if obj_traits_for_pred
            traits.add(obj_traits_for_pred)
            group_type = :both
          end
        end

        group = new(pred, group_type)
        grouped_traits[group] = traits
      end

      obj_traits_by_pred.each do |pred, traits|
        grouped_traits[new(pred, :object)] = traits
      end

      { all_traits: all_traits, grouped_traits: grouped_traits }
    end

    private
    def build_traits_by_pred(rows, traits_by_id)
      rows.map do |row|
        pred = row[:group_predicate]
        trait_pks = row[:trait_pks]
        count = row[:trait_count]
        traits = trait_pks.map { |pk| traits_by_id[pk] }
        [pred, TraitListWithCount.new(traits, count)]
      end.to_h
    end

    def extract_grouped_trait_pks(pks_by_group)
      pks_by_group.map { |row| row[:trait_pks] }.flatten
    end

    def subj_trait_pks_for_page(page_node, options)
      trait_pks_for_page_helper(page_node, :subject, '(page)-[:trait|:inferred_trait]->(trait:Trait)', options)
    end

    def obj_trait_pks_for_page(page_node, options) 
      trait_pks_for_page_helper(page_node, :object, '(trait:Trait)-[:object_page]->(page)', options)
    end

    def trait_pks_for_page_helper(page_node, group_type, trait_match, options)
      key = "trait_pks_for_page_helper/#{page_node.id}/#{group_type}"
      TraitBank::Caching.add_hash_to_key(key, options)

      Rails.cache.fetch(key) do
        group_limit_str = options[:limit] ? "[0..#{options[:limit]}]" : ''
        collect_pk_str = "collect(DISTINCT trait.eol_pk)#{group_limit_str}"

        if options[:selected_group] && options[:selected_group].include_type?(group_type)
          collect_pk_part = "CASE WHEN group_predicate.eol_id = #{options[:selected_group].term_id} THEN  #{collect_pk_str} ELSE [] END AS trait_pks"
        else
          collect_pk_part = "#{collect_pk_str} AS trait_pks"
        end

        query = page_node.query_as(:page)
          .match(trait_match)
          .match('(trait)-[:predicate]->(predicate:Term)')
          .match('(predicate)-[:synonym_of*0..]->(group_predicate:Term)')
          .where_not('(group_predicate)-[:synonym_of]->(:Term)')

        if options[:resource]
          query = query
            .match('(trait)-[:supplier]->(resource:Resource)')
            .where('resource.resource_id': options[:resource].id)
        end

        # NOTE: break needed to achieve correct ordering of where clauses
        query.break.optional_match(TraitBank::Constants::EXEMPLAR_MATCH)
          .with(:group_predicate, :trait)
          .order_by('group_predicate.eol_id', TraitBank::Constants::EXEMPLAR_ORDER)
          .return(:group_predicate, collect_pk_part, "count(DISTINCT trait) as trait_count").to_a
      end
    end
  end

  private
  TraitListWithCount = Struct.new(:traits, :count) do 
    def add(other)
      traits.concat(other.traits)
      self.count += other.count
    end
  end

  class TraitWithPageRole
    delegate_missing_to :trait
    attr_accessor :page_role, :trait

    VALID_ROLES = [:subject, :object]

    def initialize(trait, page_role)
      raise TypeError, "invalid role: #{page_role}" unless VALID_ROLES.include?(page_role)

      @trait = trait
      @page_role = page_role
    end
  end
end

