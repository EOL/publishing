# Reindex the pages in a batchable, resumable, update-mistakes-only way.
class Page::Reindexer
  def initialize(start_page_id = nil)
    @start_page_id = start_page_id || 1
    @log = Logger.new(Rails.root.join('public', 'data', 'page_reindex.log'))
    Searchkick.timeout = 500
  end

  def start
    log("START")
    log("Skipping to page #{@start_page_id}") unless @start_page_id == 1
    current_page_id = @start_page_id
    ticks = 0
    begin
      Page.search_import.where(['id >= ?', @start_page_id]).find_in_batches(batch_size: 250) do |pages|
        current_page_id = pages.first.id
        begin
          Page.search_index.bulk_update(pages, :search_data)
        rescue Searchkick::ImportError
          Page.search_index.bulk_index(pages)
        rescue Faraday::ConnectionFailed
          pages.each do |page|
            begin
              page.reindex
            rescue => e
              log("Indexing page #{page.id} FAILED. Skipping. Error: #{e.message}")
            end
          end
        end
      end
      ticks += 1
      if ticks > 10
        log("Completed up to page #{pages.last.id}")
        ticks = 0
      end
    rescue => e
      log("DIED: restart with ID #{current_page_id}")
      raise(e)
    end
  end

  def log(msg)
    @log.warn("[#{Time.now.strftime('%F %T')}] #{msg}")
  end
end
