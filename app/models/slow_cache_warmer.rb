require 'net/http'

# Hits publishing-nginx (not Rails directly) so proxy_cache is populated for every
# native-hierarchy page and its tabs. Intended to run only during off-hours:
# weeknights from 5 PM PT until 9 AM ET, plus all weekend (Fri 5 PM PT → Mon 9 AM ET).
# Persists a node-id cursor so each night continues where the previous run stopped.
class SlowCacheWarmer
  NGINX_HOST = 'publishing-nginx'
  TABS = %w[data media articles maps names].freeze
  PAGE_SLEEP = 0.25
  BATCH_SIZE = 2000
  PT_ZONE = 'America/Los_Angeles'
  ET_ZONE = 'America/New_York'
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 300

  class << self
    def warm(ignore_window: false)
      return unless ignore_window || in_warming_window?

      FileUtils.mkdir_p(state_dir)
      File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
        # Another SlowCacheWarmer is already running (e.g. weekend stretch still going).
        return unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        begin
          warm_pages(ignore_window: ignore_window)
        ensure
          lock.flock(File::LOCK_UN)
        end
      end
    end

    # Off-hours + weekend. App timezone is Eastern; PT/ET handled explicitly here.
    def in_warming_window?(time = Time.current)
      pt = time.in_time_zone(PT_ZONE)
      et = time.in_time_zone(ET_ZONE)
      return true if pt.saturday? || pt.sunday?

      pt.hour >= 17 || et.hour < 9
    end

    private

    def warm_pages(ignore_window:)
      cursor = read_cursor
      public_host = Rails.env.production? ? 'eol.org' : 'publishing-staging.apps.eol-talos.si.edu'
      finished = true

      scope = Node.where(resource_id: Resource.native.id).where.not(page_id: nil)
      scope = scope.where('nodes.id > ?', cursor) if cursor.positive?

      scope.select(:id, :page_id).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        unless ignore_window || in_warming_window?
          finished = false
          break
        end

        batch.each do |node|
          unless ignore_window || in_warming_window?
            finished = false
            break
          end

          warm_page(node.page_id, public_host)
          write_cursor(node.id)
          sleep(PAGE_SLEEP)
        end

        break unless finished

        # Long-running job: don't hold a stale DB connection overnight.
        ActiveRecord::Base.clear_active_connections!
      end

      # Full pass complete — start over next window.
      write_cursor(0) if finished
    end

    def warm_page(page_id, public_host)
      paths = ["/pages/#{page_id}"] + TABS.map { |tab| "/pages/#{page_id}/#{tab}" }
      Net::HTTP.start(NGINX_HOST, 80, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        paths.each do |path|
          req = Net::HTTP::Get.new(path)
          req['Host'] = public_host
          req['X-Forwarded-Proto'] = 'https'
          http.request(req)
        end
      end
    rescue StandardError => e
      Rails.logger.warn("SlowCacheWarmer: failed page #{page_id}: #{e.class}: #{e.message}")
    end

    def state_dir
      Rails.public_path.join('data')
    end

    def cursor_path
      state_dir.join('slow_cache_warmer_cursor.txt')
    end

    def lock_path
      state_dir.join('slow_cache_warmer.lock')
    end

    def read_cursor
      return 0 unless File.exist?(cursor_path)

      File.read(cursor_path).to_i
    end

    def write_cursor(node_id)
      File.open(cursor_path, 'w') { |f| f.write(node_id.to_s) }
    end
  end
end
