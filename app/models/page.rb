class Page < ActiveRecord::Base
  belongs_to :native_node, class_name: "Node"
  belongs_to :moved_to_page, class_name: "Page"

  has_many :nodes, inverse_of: :page

  has_many :vernaculars, inverse_of: :page
  has_many :preferred_vernaculars, -> { where(is_preferred: true) },
    class_name: "Vernacular"
  has_many :scientific_names, inverse_of: :page
  has_one :name, -> { where(is_preferred: true) }, class_name: "ScientificName"

  has_many :page_contents, -> { order(:position) }, as: :page
  # TODO: test that the order is honored, here.
  has_many :maps, through: :page_contents, source: :content, source_type: "Map"
  has_many :articles, through: :page_contents, source: :content, source_type: "Article"
  has_many :media, through: :page_contents, source: :content, source_type: "Medium"
  has_many :links, through: :page_contents, source: :content, source_type: "Link"

  scope :preloaded, -> do
    includes(:name, :preferred_vernaculars)
  end

  def common_name(language = nil)
    language ||= Language.english
    preferred_vernaculars.find { |v| v.language_id == language.id }
  end
end
