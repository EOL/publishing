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

  before_validation :cull_filters

  def initialize(*)
    super
  end

  def filters=(the_filters)
    self.numeric_filters     = the_filters.select { |f| f.is_a? TermQueryNumericFilter    } 
    self.range_filters       = the_filters.select { |f| f.is_a? TermQueryRangeFilter      }
    self.object_term_filters = the_filters.select { |f| f.is_a? TermQueryObjectTermFilter }
    self.predicate_filters   = the_filters.select { |f| f.is_a? TermQueryPredicateFilter  }
  end

  def filters
    [numeric_filters, range_filters, object_term_filters, predicate_filters].flatten
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

  private
    def cull_filters
      self.filters = search_filters
    end
end
