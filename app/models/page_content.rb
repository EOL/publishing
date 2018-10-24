class PageContent < ActiveRecord::Base
  belongs_to :page
  belongs_to :source_page, class_name: "Page"
  belongs_to :content, polymorphic: true, inverse_of: :page_contents
  belongs_to :association_add_by_user, class_name: "User"

  has_many :curations

  default_scope { order(:position) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  scope :sources, -> { where("source_page_id = page_id") }

  scope :visible, -> { where(is_hidden: false) }
  scope :hidden, -> { where(is_hidden: true) }

  scope :trusted, -> { where(trust: PageContent.trusts[:trusted]) }
  scope :untrusted, -> { where(trust: PageContent.trusts[:untrusted]) }
  scope :not_untrusted, -> { where.not(trust: PageContent.trusts[:untrusted]) }

  scope :articles, -> { where(content_type: "Article") }

  scope :media, -> { where(content_type: "Medium") }

# TODO: make sure these both work.
  counter_culture :page
  counter_culture :page,
    column_name: proc { |model| "#{model.content_type.pluralize.downcase}_count" },
    column_names: {
      ["page_contents.content_type = ?", "Medium"] => "media_count",
      ["page_contents.content_type = ?", "Article"] => "articles_count",
      ["page_contents.content_type = ?", "Link"] => "links_count"
    }

  # TODO: think about this. We might want to make the scope [:page,
  # :content_type]... then we can interlace other media types (or always show
  # them separately, which I think has advantages)
  acts_as_list scope: :page

  def self.fix_exemplars
    # NOTE: this does NOT restrict by content_type because that slows the query WAAAAAAY down (it's not indexed)
    page_ids = uniq.pluck(:page_id)
    batches = (page_ids.size / 1000).ceil
    puts "++ Cleaning up #{page_ids.size} exemplars (#{batches} batches)..."
    batch = 1
    page_ids.in_groups_of(1000, false) do |group|
      puts "++ Batch #{batch}/#{batches}..."
      # NOTE: The #search_import is required because we're going to update Search... without that scope added, we end up
      # doing dozens of extra DB queries to build the Search JSON!
      Page.search_import.where(id: group).find_each do |page|
        # NOTE: yes, this will produce a query for EVERY page in the array. ...But it's very hard to limit the number of results from a join, and this isn't a method we'll run very often, so this is "Fine."
        medium_id = page.media.limit(1).pluck(:id).first
        page.update_attribute(:medium_id, medium_id) unless page.medium_id == medium_id
      end
      batch += 1
    end
    puts "++ Done."
  end

  def self.export_for_ordering
    require 'csv'
    collection_num = 1
    collection = []
    puts "start #{Time.now}"
    # NOTE: YES! Really, one at a time was *fastest*. Go. Figure.
    Page.select('id').find_each do |page|
      where(page_id: page.id).visible.not_untrusted.media.includes(:content).find_each do |item|
        collection << [item.content_id, item.page_id, item.content.source_url, item.position]
        if collection.size >= 10_000
          flush_collection(collection, collection_num)
          collection = []
          collection_num += 1
          puts "flushed ##{collection_num - 1} @ #{Time.now}"
        end
      end
    end
    puts "end #{Time.now}"
    flush_collection(collection, collection_num) unless collection.empty?
  end

  def self.flush_collection(collection, collection_num)
    CSV.open(Rails.root.join('public', "images_for_sorting_#{collection_num}.csv"), 'wb') do |csv|
      csv << %w[eol_pk page_id source_url position]
      collection.each { |row| csv << row }
    end
  end
end
