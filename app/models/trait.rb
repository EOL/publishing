# Bridge between TraitNodes and their associated ActiveRecord models (e.g., Page, Resource)
# Efficiently loads these associated models in batches.
# TODO: should this live in app/models or lib? It behaves like a model (and is intended to be used as such), so maybe this is the right place?
class Trait
  attr_accessor :trait_node
  delegate_missing_to :trait_node

  def initialize(trait_node, record_assocs)
    @trait_node = trait_node
    @record_assocs = record_assocs
  end

  private_class_method :new # use for_eol_pks

  # TODO: can/should these be generalized?
  def resource
    @resource ||= @record_assocs.resource(@trait_node.resource&.resource_id)
  end

  def page
    @page ||= @record_assocs.page(@trait_node.page&.page_id)
  end

  def object_page
    @object_page ||= @record_assocs.page(@trait_node.object_page&.page_id)
  end

  class << self
    def find(eol_pk)
      wrap_node(TraitNode.find(eol_pk))
    end

    # Factory method
    def for_eol_pks(eol_pks)
      nodes = TraitNode.where(eol_pk: eol_pks)
        .with_associations(
          :predicate, 
          :object_term, 
          :units_term, 
          :lifestage_term, 
          :statistical_method_term, 
          :sex_term, 
          :object_page, 
          :page, 
          :resource
        ) 

      record_assocs = RecordAssociations.new(nodes)
      nodes.map { |n| new(n, record_assocs) }
    end
    
    def for_page_trait_predicate_groups(page, groups, options = {})
      subj_groups = groups.select { |g| g.subject? }
      obj_groups = groups.select { |g| g.object? }
      subj_trait_pks_by_group = page_subj_trait_pks_by_group(page, subj_groups, options) 
      obj_trait_pks_by_group = page_obj_trait_pks_by_group(page, obj_groups, options) 
      all_trait_pks = (
        extract_grouped_trait_pks(subj_trait_pks_by_group) +
        extract_grouped_trait_pks(obj_trait_pks_by_group)
      ).uniq
      all_traits = for_eol_pks(all_trait_pks)
      all_traits_by_id = all_traits.map { |t| [t.id, t] }.to_h

      subj_traits_by_pred = build_traits_by_pred(subj_trait_pks_by_group, all_traits_by_id)
      obj_traits_by_pred = build_traits_by_pred(obj_trait_pks_by_group, all_traits_by_id)

      grouped_traits = {}

      subj_traits_by_pred.each do |pred, traits|
        obj_traits = obj_traits_by_pred.delete(pred)

        if obj_traits
          traits.add(obj_traits)
          group = PageTraitPredicateGroup.new(pred, :both)
        else
          group = PageTraitPredicateGroup.new(pred, :subject)
        end

        grouped_traits[group] = traits
      end

      obj_traits_by_pred.each do |pred, traits|
        group = PageTraitPredicateGroup.new(pred, :object)
        grouped_traits[group] = traits
      end

      { all_traits: all_traits, grouped_traits: grouped_traits }
    end

    def wrap_node(trait_node)
      return nil if trait_node.nil?
      new(trait_node, RecordAssociations.new([trait_node]))
    end

    def populate_pk_result(result)
      result_a = result.to_a
      traits_by_id = for_eol_pks(result_a.map { |row| row[:trait_pk] }).map { |t| [t.id, t] }.to_h
      value = result_a.map do |row|
        row_h = row.to_h
        row_h[:trait] = traits_by_id[row[:trait_pk]]
        row_h
      end

      value
    end

    private
    def page_subj_trait_pks_by_group(page, groups, options)
      page_trait_pks_by_group_helper(page, groups, '(page)-[:trait|:inferred_trait]->(trait:Trait)', options)
    end

    def page_obj_trait_pks_by_group(page, groups, options)
      page_trait_pks_by_group_helper(page, groups, '(trait:Trait)-[:object_page]->(page)', options)
    end

    def page_trait_pks_by_group_helper(page, groups, trait_match, options)
      raise ':limit option required for multiple groups' if groups.length > 1 && !options[:limit]
      group_limit_str = options[:limit] ? "[0..#{options[:limit]}]" : ''

      query = page.page_node.query_as(:page)
        .match(trait_match)
        .match("(trait)-[:predicate]->(:Term)-[#{TraitBank::Constants::PARENT_TERMS}]->(group_predicate:Term)")
        .where('group_predicate.eol_id': groups.map { |g| g.term_id })

      if options[:resource]
        query = query
          .match('(trait)-[:supplier]->(resource:Resource)')
          .where('resource.resource_id': options[:resource].id)
      end

      # 'break' necessary to force the above where clauses to apply to the MATCH rather than OPTIONAL MATCH :(
      query.break.optional_match(TraitBank::Constants::EXEMPLAR_MATCH)
        .with(:group_predicate, :trait)
        .order_by('group_predicate.eol_id', TraitBank::Constants::EXEMPLAR_ORDER)
        .return(:group_predicate, "collect(DISTINCT trait.eol_pk)#{group_limit_str} AS trait_pks, count(DISTINCT trait) as trait_count").to_a
    end

    def build_traits_by_pred(rows, traits_by_id)
      rows.map do |row|
        pred = row[:group_predicate]
        trait_pks = row[:trait_pks]
        count = row[:trait_count]
        traits = trait_pks.map { |pk| traits_by_id[pk] }
        [pred, ListWithCount.new(traits, count)]
      end.to_h
    end

    def extract_grouped_trait_pks(pks_by_group)
      pks_by_group.map { |row| row[:trait_pks] }.flatten
    end

    # end private
  end
  # end class << self

  private
  ListWithCount = Struct.new(:traits, :count) do 
    def add(other)
      traits.concat(other.traits)
      self.count += other.count
    end
  end

  class RecordAssociations
    def initialize(trait_nodes)
      @trait_nodes = trait_nodes
    end

    def resource(id)
      return nil if id.nil?

      @resources ||= Resource.where(id: @trait_nodes.map { |t| t.resource&.resource_id }.uniq)
        .map { |r| [r.id, r] }.to_h

      @resources[id]
    end

    def page(id)
      return nil if id.nil?

      unless @pages
        page_ids = []

        @trait_nodes.each do |t|
          page_ids << t.page.id if t.page
          page_ids << t.object_page.id if t.object_page
        end

        @pages = Page.where(id: page_ids.uniq).map { |p| [p.id, p] }.to_h
      end

      @pages[id]
    end

  end
  # end private
end
