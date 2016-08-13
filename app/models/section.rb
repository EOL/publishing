class Section < ActiveRecord::Base
  has_many :content_sections
  belongs_to :parent, class_name: "Section"

  default_scope { order(:position) }

  has_many :content_sections
  has_many :contents, through: :content_sections
  has_many :children, class_name: "Section", foreign_key: "parent_id", inverse_of: :parent

  acts_as_list

  class << self
    def best_overviews
      # TODO: we really should add positions to these... and creating them should
      # all happen at once, not individually:
      [ brief_summary, comprehensive_description, distribution ]
    end

    def brief_summary
      @brief_summary ||= Section.where(name: "brief_summary").first_or_create do |s|
        s.name = "brief_summary"
      end
    end

    def comprehensive_description
      @comprehensive_description ||= Section.where(name: "comprehensive_description").first_or_create do |s|
        s.name = "comprehensive_description"
      end
    end

    def distribution
      @distribution ||= Section.where(name: "distribution").first_or_create do |s|
        s.name = "distribution"
      end
    end
  end
end
