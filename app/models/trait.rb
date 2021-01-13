# Not an ActiveRecord model, but behaves kind of like one.
class Trait
  private_class_method :new # use for_eol_pks
  attr_accessor :trait_node
  delegate_missing_to :trait_node

  def initialize(trait_node, record_assocs)
    @trait_node = trait_node
    @record_assocs = record_assocs
  end

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

  # eol_pks -- array of String
  def self.for_eol_pks(eol_pks)
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
    nodes.map { |n| self.new(n, record_assocs) }
  end

  private
  class RecordAssociations
    def initialize(trait_nodes)
      @trait_nodes = trait_nodes
    end

    def resource(id)
      return nil if id.nil?

      @resources ||= Resource.where(id: @trait_nodes.map { |t| t.resource&.resource_id })
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

        @pages = Page.where(id: page_ids).map { |p| [p.id, p] }.to_h
      end

      @pages[id]
    end
  end
end
