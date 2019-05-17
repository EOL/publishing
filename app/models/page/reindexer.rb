# Reindex the pages in a batchable, resumable, update-mistakes-only way.
class Page::Reindexer
  # Pass throttle: nil to skip throttling.
  def initialize(start_page_id = nil, options = {})
    @start_page_id = start_page_id || 1
    @log = Logger.new(Rails.root.join('public', 'data', 'page_reindex.log'))
    @throttle = options.has_key?(:throttle) ? options[:throttle] : 0.5
    @batch_size = options.has_key?(:batch_size) ? options[:batch_size] : 100
    Searchkick.client_options = {
      retry_on_failure: true,
      transport_options: { request: { timeout: 500 } }
    }
    Searchkick.timeout = 500
  end

  def start
    log('START')
    log("Skipping to page #{@start_page_id}") unless @start_page_id == 1
    current_page_id = @start_page_id
    begin
      count = Page.search_import.where(['id >= ?', @start_page_id]).count
      log("Total pages to index: #{count}")
      batches = count / @batch_size + 1
      batch = 0
      Page.search_import.where(['id >= ?', @start_page_id]).find_in_batches(batch_size: @batch_size) do |pages|
        batch += 1
        current_page_id = pages.first.id
        begin
          Page.search_index.bulk_update(pages, :search_data)
        rescue Searchkick::ImportError
          log("An update failed (starting with page #{current_page_id}), trying index")
          Page.search_index.bulk_index(pages)
        rescue Faraday::ConnectionFailed
          log("Connection failed (starting with page #{current_page_id}), you may want to check any other scripts that were running. Retrying...")
          sleep(@throttle * 5) if @throttle
          pages.each do |page|
            begin
              current_page_id = page.id
              page.reindex
              sleep(@throttle) if @throttle # Ouch. Sleeping per page is ugly!
            rescue => e
              log("Indexing page #{page.id} FAILED. Skipping. Error: #{e.message}")
            end
          end
        end
        sleep(@throttle) if @throttle
        naglessly do
          pct = (batch.to_f / batches * 1000).ceil / 10.0
          log("#{pages.last.id} (batch #{batch}/#{batches}, #{pct}%)")
        end
      end
    rescue => e
      log("DIED: restart with ID #{current_page_id}")
      raise(e)
    end
  end

  def naglessly
    @last_msg ||= 31.seconds.ago
    if @last_msg < 30.seconds.ago
      yield
      @last_msg = Time.now
    end
  end

  def log(msg)
    @log.warn("[#{Time.now.strftime('%F %T')}] #{msg}")
  end
end
