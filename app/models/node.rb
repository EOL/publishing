class Node < ActiveRecord::Base
  belongs_to :page, inverse_of: :nodes
  belongs_to :resource, inverse_of: :nodes
  belongs_to :rank

  has_one :taxon_remark, inverse_of: :node

  # TODO: do we need these with acts_as_nested_set?
  has_many :scientific_names, inverse_of: :node
  has_many :vernaculars, inverse_of: :node
  has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"

  has_many :references, as: :parent
  has_many :referents, through: :references

  acts_as_nested_set scope: :resource, counter_cache: :children_count

  counter_culture :resource
  counter_culture :page

  # TODO: this is duplicated with page; fix.
  def name(language = nil)
    language ||= Language.find_by_group(I18n.locale)
    vernacular(language).try(:string) || scientific_name
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
end
