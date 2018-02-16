class TermQuery < ActiveRecord::Base
  has_many :filters,
    :class_name => "TermQueryFilter",
    :inverse_of => :term_query,
    :dependent => :destroy
#  has_many :pairs, 
#    :class_name => "TermQueryPair", 
#    :inverse_of => :term_query,
#    :dependent => :destroy
  has_one :user_download, :dependent => :destroy
#  accepts_nested_attributes_for :pairs
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
