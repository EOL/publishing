class TermQuery < ActiveRecord::Base
  has_many :numeric_filters,
    :class_name => "TermQueryNumericFilter",
    :dependent => :destroy
  has_many :range_filters,
    :class_name => "TermQueryRangeFilter",
    :dependent => :destroy
  has_many :object_term_filters,
    :class_name => "TermQueryObjectTermFilter",
    :dependent => :destroy
  has_many :predicate_filters,
    :class_name => "TermQueryPredicateFilter",
    :dependent => :destroy
  has_one :user_download, :dependent => :destroy

  accepts_nested_attributes_for :numeric_filters
  accepts_nested_attributes_for :range_filters
  accepts_nested_attributes_for :object_term_filters
  accepts_nested_attributes_for :predicate_filters

#  before_validation :cull_pairs

  def initialize(*)
    super
  end

#  def search_pairs
#    pairs.select do |pair|
#      !pair.predicate.blank?
#    end
#  end


#  def remove_pair(index)
#    new_pairs = pairs.to_a
#    new_pairs.delete_at(index)
#    self.pairs = new_pairs
#  end

  def clade_name
    if clade
      @clade_name ||= Page.find(clade)&.name.gsub(/<[^>]+>/, '')
    else
      nil
    end
  end

  private
#    def cull_pairs
#      self.pairs = search_pairs
#    end
end
