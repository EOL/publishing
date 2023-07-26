class PageContent < ApplicationRecord
  belongs_to :page
  belongs_to :source_page, class_name: "Page"
  belongs_to :content, polymorphic: true, inverse_of: :page_contents
  belongs_to :association_add_by_user, class_name: "User", optional: true

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

  counter_culture :page
  counter_culture :page,
    column_name: proc { |model| "#{model.content_type.pluralize.downcase}_count" },
    column_names: {
      ["page_contents.content_type = ?", "Medium"] => "media_count",
      ["page_contents.content_type = ?", "Article"] => "articles_count",
      ["page_contents.content_type = ?", "Link"] => "links_count"
    }

  acts_as_list scope: :page

  class << self
    def fix_duplicate_positions(page_id)
      PageContent.connection.execute("SET @rownum = 0;")
      PageContent.connection.execute(
        "UPDATE page_contents pc JOIN (\n"\
          "SELECT (@rownum :=@rownum + 1) row_num, id FROM page_contents WHERE page_id = #{page_id} ORDER BY position ASC\n"\
        ") nums ON pc.id = nums.id\n"\
        "SET pc.position = nums.row_num;"
      )

      exemplar = Page.find(page_id).page_icon&.page_content

      if exemplar
        exemplar.move_to_top
      end
    end

    # Note: this is not meant to be fast.
    def remove_all_orphans
      [Medium, Article].each do |klass|
        puts "=== #{klass.name}"
        Page.in_batches(of: 32) do |pages|
          page_ids = pages.pluck(:id)
          puts "PAGES: #{page_ids[0..3].join(',')}... (#{page_ids.count})\n\n"
          STDOUT.flush
          content_ids = PageContent.where(page_id: page_ids, content_type: klass.name).pluck(:content_id)
          puts "CONTENTS [#{page_ids.first}+]: #{content_ids[0..3].join(',')}... (#{content_ids.count})\n\n"
          # missing_ids = content_ids - klass.where(id: content_ids).pluck(:id)
          content_ids.each_slice(10_000) do |content_batch| 
            STDOUT.flush
            missing_ids = content_batch - klass.where(id: content_batch).pluck(:id)
            puts "MISSING (#{content_batch.first}...) [#{page_ids.first}+]: #{missing_ids.size}"
            # puts "REMOVED: #{PageContent.where(page_id: page_ids, content_id: missing_ids, content_type: klass.name).count}"
            # puts "FIND: PageContent.where(page_id: page_ids, content_id: #{missing_ids.first}, content_type: '#{klass.name}')"
            puts "REMOVED [#{page_ids.first}+]: #{PageContent.where(page_id: page_ids, content_id: missing_ids, content_type: klass.name).delete_all}"
          end
          puts "+++ Batch Completed (#{klass})..."
          STDOUT.flush
        end
      end
      puts "=== Complete."
      STDOUT.flush
    end
  end # of class methods
end
