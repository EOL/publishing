class TermQuery < ApplicationRecord
  has_many :filters,
    :class_name => "TermQueryFilter",
    :dependent => :destroy,
    :inverse_of => :term_query
  validates_associated :filters
  has_many :user_downloads, dependent: :destroy
  has_many :gbif_downloads, dependent: :destroy
  belongs_to :clade, :class_name => "Page", optional: true
  validates_presence_of :result_type
  validate :validation
  validates_uniqueness_of :digest, unless: Proc.new { |q| q.digest.nil? }

  enum :result_type => { :record => 0, :taxa => 1 }

  accepts_nested_attributes_for :filters

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
    attrs << "result_type: #{result_type}"
    "&&TermQuery.new(#{attrs.join(',')}) "
  end

  def to_cache_key
    parts = ["term_query"]
    parts << "clade_#{clade_id}" if clade_id
    parts << filters.map(&:to_cache_key).join('/') unless filters.empty?
    parts << "type_#{result_type}"
    parts.join('/')
  end

  # NOTE: this method is never called; it's used in a console.
  def run(options = {})
    options.reverse_merge(per: 10, page: 1, result_type: :record) # Smaller number for console testing.
    TraitBank.term_search(self, options)[:data]
  end

  def to_params
    {
      result_type: result_type,
      clade_id: clade&.id,
      filters_attributes: filters.collect { |f| f.to_params }
    }
  end

  def remove_really_blank_filters
    self.filters = self.filters.reject { |f| f.really_blank? }
  end

  def add_filter_if_none
    self.filters.build if filters.empty?
  end

  def filters_inv_pred_last
    self.filters.sort do |a, b|
      if a.inverse_pred_uri && !b.inverse_pred_uri
        1
      elsif !a.inverse_pred_uri && b.inverse_pred_uri
        -1
      else
        0
      end
    end
  end

  def deep_dup
    copy = dup
    copy.filters = self.filters.collect { |f| f.dup }
    copy
  end

  # You MUST call this method if you want a digest saved along with the record. At the time of writing, this was only used by UserDownloads, and adding callbacks/validations messed with trait search.
  def build_digest
    Digest::MD5.hexdigest(self.to_cache_key)
  end

  def refresh_digest
    self.digest = build_digest
  end

  def clade_node
    if clade
      @clade_node ||= PageNode.find(clade.id)
    else
      nil
    end
  end

  class << self
    def find_saved(new_query)
      digest = new_query.build_digest
      TermQuery.find_by_digest(digest)
    end

    def find_or_save!(new_query)
      new_query.refresh_digest
      query = TermQuery.find_by_digest(new_query.digest)

      if query.nil?
        new_query.save!
        query = new_query
      end

      query
    end

    def expected_params
      [
        :clade_id,
        :result_type,
        :filters_attributes => [
          :pred_uri,
          :top_pred_uri,
          :obj_uri,
          :obj_clade_id,
          :op,
          :num_val1,
          :num_val2,
          :units_uri,
          :sex_uri,
          :lifestage_uri,
          :statistical_method_uri,
          :resource_id,
          :show_extra_fields,
          :pred_term_selects_attributes => [
            :type,
            :parent_uri,
            :selected_uri
          ],
          :obj_term_selects_attributes => [
            :type,
            :parent_uri,
            :selected_uri
          ]
        ]
      ]
    end
  end

  def page_count_sorted_filters
    @page_count_sorted_filters ||= filters.sort { |a, b| a.min_distinct_page_count <=> b.min_distinct_page_count }
  end

  private
  def validation
    if filters.empty?
      if taxa? && clade.nil?
        errors.add(:base, I18n.t("term_query.validations.empty_filters_error_taxa"))
      elsif record?
        add_filter_if_none
        filters.first.valid? # To trigger error on field as well. This is scary (side-effects in validation??) but convenient.
        errors.add(:base, I18n.t("term_query.validations.empty_filters_error_record"))
      end
    end
  end
end
