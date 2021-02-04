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
    @type == :subject || @type == :both
  end

  def object?
    @type == :object || @type == :both
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

  class << self
    include TraitBank::Constants

    def for_page(page, options = {})
      key = "page_trait_predicate_group/for_page/#{page.id}"
      TraitBank::Caching.add_hash_to_key(key, options)

      Rails.cache.fetch(key) do
        subj_preds = subj_preds_for_page(page.page_node, options)
        obj_preds = obj_preds_for_page(page.page_node, options)
        obj_preds_by_id = obj_preds.map { |p| [p.id, p] }.to_h
        groups = []

        subj_preds.each do |p|
          group = if obj_preds_by_id.delete(p.id)
                    new(p, :both)
                  else
                    new(p, :subject)
                  end

          groups << group
        end

        obj_preds_by_id.values.each do |p|
          groups << new(p, :object)
        end

        groups.sort { |a, b| a.name.downcase <=> b.name.downcase }
      end
    end

    private
    def subj_preds_for_page(page_node, options)
      preds_for_page_helper(page_node, '(page)-[:trait|:inferred_trait]->(trait:Trait)', options)
    end

    def obj_preds_for_page(page_node, options) 
      preds_for_page_helper(page_node, '(trait:Trait)-[:object_page]->(page)', options)
    end

    def preds_for_page_helper(page_node, trait_match, options)
      query = page_node.query_as(:page)
        .match(trait_match)
        .match('(trait)-[:predicate]->(predicate:Term)')
        .match("(predicate)-[#{PARENT_TERMS}]->(group_predicate:Term)")
        .where_not('(group_predicate)-[:synonym_of]->(:Term)')

      if options[:resource]
        query = query
          .match('(trait)-[:supplier]->(resource:Resource)')
          .where('resource.resource_id': options[:resource].id)
      end

      query.with_distinct(:group_predicate)
        .proxy_as(TermNode, :group_predicate)
    end
  end
end
