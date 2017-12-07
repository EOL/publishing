class TermQuery < ActiveRecord::Base
  has_many :pairs, :class_name => "TermQueryPair"
  accepts_nested_attributes_for :pairs

  def initialize(*)
    super
  end

  def search_pairs
    pairs.select do |pair|
      !pair.predicate.blank?
    end
  end

  def remove_pair(index)
    new_pairs = pairs.to_a
    new_pairs.delete_at(index)
    self.pairs = new_pairs
  end

  def clade_name
    if @clade
      @clade_name ||= Page.find(@clade)&.name
    else
      nil
    end
  end
end
