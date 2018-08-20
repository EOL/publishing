class TermQuery < ActiveRecord::Base
  has_many :filters,
    :class_name => "TermQueryFilter",
    :dependent => :destroy,
    :inverse_of => :term_query
  validates_associated :filters
  has_one :user_download, :dependent => :destroy
  belongs_to :clade, :class_name => "Page"
  validates_presence_of :result_type

  enum :result_type => { :record => 0, :taxa => 1 }

  accepts_nested_attributes_for :filters

  def search_filters
    filters.reject { |f| f.invalid? }
  end

  def predicate_filters
    filters.select { |f| f.predicate? }
  end

  def object_term_filters
    filters.select { |f| f.object_term? }
  end

  def numeric_filters
    filters.select { |f| f.numeric? }
  end

  def range_filters
    filters.select { |f| f.range? }
  end

  def to_s
    attrs = []
    attrs << "clade_id: #{clade_id}" if clade_id
    attrs << "filters_attributes: [#{filters.map(&:to_s).join(', ')}]"
    "&&TermQuery.new(#{attrs.join(',')}) "
  end

  # NOTE: this method is never called; it's used in a console.
  def run(options = {})
    options.reverse_merge(per: 10, page: 1, result_type: :record) # Smaller number for console testing.
    TraitBank.term_search(self, options)[:data]
  end
end
