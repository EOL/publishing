class TermQuery < ActiveRecord::Base
  has_many :filters,
    :class_name => "TermQueryFilter",
    :dependent => :destroy
  has_one :user_download, :dependent => :destroy

  accepts_nested_attributes_for :filters

  def initialize(*)
    super
  end

  def search_filters
    filters.reject { |f| f.invalid? }
  end

  def clade_name
    if clade
      @clade_name ||= Page.find(clade)&.name.gsub(/<[^>]+>/, '')
    else
      nil
    end
  end

  def self.filter_types_for_pred(uri)
    types = [:predicate]

    types << :object_term if TraitBank::Terms.obj_terms_for_pred(uri).any?
    
    types += [
      :numeric,
      :range
    ] if TraitBank::Terms.unit_term_for_pred(uri)

    types
  end

  private
end
