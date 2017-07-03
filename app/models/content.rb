module Content
  extend ActiveSupport::Concern

  included do
    include Content
    searchkick

    belongs_to :resource
    belongs_to :language

    has_many :content_sections, as: :content
    has_many :sections, through: :content_sections
    has_many :page_contents, as: :content
    has_many :pages, through: :page_contents
    has_many :curations, through: :page_contents

    has_many :references, as: :parent
    has_many :referents, through: :references

    has_many :associations, -> { where("page_id = source_page_id") },
      through: :page_contents, source: :page

    def search_fields
      # NOTE: description is a method because articles have a body; we use an
      # alias to normalize it.
      {
        id: id,
        name: name,
        resource_pk: resource_pk,
        owner: owner,
        ancestor_ids: ancestor_ids,
        description: description
      }
    end

    def ancestor_ids
      page_contents.pluck(:page_id)
    end
  end

end
