class Node < ActiveRecord::Base
  belongs_to :page, inverse_of: :nodes
  belongs_to :parent, class_name: 'Node', inverse_of: :children
  belongs_to :resource, inverse_of: :nodes
  belongs_to :rank

  has_many :identifiers, inverse_of: :node
  has_many :scientific_names, inverse_of: :node
  has_many :vernaculars, inverse_of: :node
  has_many :preferred_vernaculars, -> { preferred }, class_name: 'Vernacular'
  has_many :node_ancestors, -> { order(:depth) }, inverse_of: :node, dependent: :destroy
  has_many :descendants, class_name: 'NodeAncestor', inverse_of: :ancestor, foreign_key: :ancestor_id
  has_many :unordered_ancestors, through: :node_ancestors, source: :ancestor
  has_many :children, class_name: 'Node', foreign_key: :parent_id, inverse_of: :parent
  has_many :references, as: :parent
  has_many :referents, through: :references

  # Denotes the context in which the (non-zero) landmark ID should be used. Additional description:
  # https://github.com/EOL/eol_website/issues/5 <-- HEY, YOU SHOULD ACTUALLY READ THAT.
  enum landmark: %i[no_landmark minimal abbreviated extended full]

  counter_culture :resource
  counter_culture :page

  # TODO: this is duplicated with page; fix.
  def name(language = nil)
    language ||= Language.current
    vernacular(language).try(:string) || scientific_name
  end

  def use_breadcrumb?
    has_breadcrumb? && (minimal? || abbreviated?)
  end

  def use_abbreviated?
    minimal? || abbreviated? || (rank && rank.r_family?)
  end

  # NOTE: this is slow and clunky and should ONLY be used when you have ONE instance. If you have multiple nodes and
  # want to call this on all of them, you should use #node_ancestors directly and pay attention to your includes and
  # ordering.
  def ancestors
    node_ancestors.map(&:ancestor)
  end

  def preferred_scientific_name
    @preferred_scientific_name ||= scientific_names.select {|n| n.is_preferred? }&.first
  end

  # NOTE: the "canonical_form" on this node is NOT italicized. In retrospect, that was a mistake, though we do need it
  # for searches. Just use this method instead of canonical_form everywhere that it's shown to a user.
  def canonical
    if scientific_names.loaded?
      preferred_scientific_name&.canonical_form
    else
      scientific_names&.preferred&.first&.canonical_form
    end
  end

  def italicized
    if scientific_names.loaded?
      preferred_scientific_name&.italicized
    else
      scientific_names&.preferred&.first&.italicized
    end
  end

  # TODO: this is duplicated with page; fix.
  # Can't (easily) use clever associations here because of language.
  def vernacular(language = nil)
    if preferred_vernaculars.loaded?
      language ||= Language.english
      preferred_vernaculars.find { |v| v.language_id == language.id }
    else
      if vernaculars.loaded?
        language ||= Language.english
        vernaculars.find { |v| v.language_id == language.id and v.is_preferred? }
      else
        language ||= Language.english
        preferred_vernaculars.find { |v| v.language_id == language.id }
      end
    end
  end

  def landmark_children(limit=10)
    children.where(landmark: [
      Node.landmarks[:minimal],
      Node.landmarks[:abbreviated],
      Node.landmarks[:extended],
      Node.landmarks[:full]
    ])
    .order(:landmark)
    .limit(limit)
  end
end
