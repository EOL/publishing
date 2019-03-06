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

  class << self
    # content_id: 9368757, page_id: 8663597
    def set_v2_exemplars(starting_page_id = nil)
      puts "[#{Time.now}] starting"
      last_flush = Time.now
      STDOUT.flush
      require 'csv'
      # Jamming this in the /public/data dir just so we can keep it between restarts!
      file = Rails.root.join('public', 'data', 'image_order.tsv')
      all_data = CSV.read(file, col_sep: "\t")
      per_cent = all_data.size / 100
      fixed_page = 0
      skipping_count = 0
      all_data[1..-1].each_with_index do |row, i|
        medium_id = row[0].to_i
        page_id = row[1].to_i
        if starting_page_id && page_id < starting_page_id.to_i
          if skipping_count.zero? || (skipping_count % 1000).zero?
            puts ".. Skipping #{page_id} (to get to #{starting_page_id}).."
            STDOUT.flush
          end
          next
        end
        if skipping_count >= 0
          puts "Starting with page #{page_id}"
          STDOUT.flush
          skipping_count = -1 # Stop notifications.
        end
        if fixed_page < page_id
          fixed_page = page_id
          fix_duplicate_positions(page_id)
          puts "[#{Time.now}] FIRST CONTENT FOR PAGE #{page_id}, % COMPLETE: #{i / per_cent}"
          STDOUT.flush
          last_flush = Time.now
        end
        order = row[2].to_i # 0-index
        last = (row[3] =~ /last/i) # 'first' or 'last'
        contents = PageContent.where(content_type: 'Medium', content_id: medium_id, page_id: page_id)
        if contents.any?
          count_on_this_page = 0
          content = contents.first # NOTE: #shift does not work on ActiveRecord_Relation, sadly.
          if contents.size > 1
            contents[1..-1].each { |extra| extra.destroy } # Remove duplicates
          end
          if last
            content.move_to_bottom # Let's not worry about the ORDER of the worst ones; I think it will naturally work.
          else
            if order.zero?
              PageIcon.create(page_id: page_id, medium_id: medium_id, user_id: 1)
              content.move_to_top
            else
              if count_on_this_page >= 100
                puts "[#{Time.now}] .. moving #{medium_id} on page #{page_id} to position #{order + 1}"
                STDOUT.flush
                count_on_this_page = 0
              end
              content.insert_at(order + 1)
            end
          end
          count_on_this_page += 1
          if (i % per_cent).zero? || last_flush < 5.minutes.ago
            puts "[#{Time.now}] % COMPLETE: #{i / per_cent}"
            STDOUT.flush
            last_flush = Time.now
          end
        else
          puts "[#{Time.now}] missing: content_type: 'Medium', content_id: #{medium_id}, page_id: #{page_id}"
          STDOUT.flush
        end
      end
      puts "[#{Time.now}] done."
      STDOUT.flush
    end

    def fix_duplicate_positions(page_id)
      exemplar = Page.find(page_id).page_icon&.medium_id
      final = PageContent.where(page_id: page_id).maximum(:position) + 1
      (0..final).each do |position|
        count_at_this_position = PageContent.where(page_id: page_id, position: position).count
        break if PageContent.where(page_id: page_id, position: position).count <= 1
        puts "[#{Time.now}] Fixing #{count_at_this_position} duplicate positions of #{position} on page #{page_id}"
        STDOUT.flush
        PageContent.where(page_id: page_id, position: position).find_each do |content|
          if exemplar.nil? || exemplar != content.content_id # Don't move the exemplar.
            content.update_attribute(:position, final)
            final += 1
          end
        end
      end
    end

    def fix_exemplars
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
          medium_id = page.media.order(:position).limit(1).pluck(:id).first
          page.update_attribute(:medium_id, medium_id) unless page.medium_id == medium_id
        end
        batch += 1
      end
      puts "++ Done."
    end

    def export_for_ordering
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

    def flush_collection(collection, collection_num)
      CSV.open(Rails.root.join('public', "images_for_sorting_#{collection_num}.csv"), 'wb') do |csv|
        csv << %w[eol_pk page_id source_url position]
        collection.each { |row| csv << row }
      end
    end
  end # of class methods
end
