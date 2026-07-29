# Soft-fail + skip Neo4j for pages whose graph store has relationship-chain
# corruption ("NOT PART OF CHAIN!"). Dump/load preserves this damage; until the
# store is rebuilt (e.g. neo4j-admin copy), avoid paying the latency + 500 cost
# of re-hitting the same page.
module TraitBank
  module Corruption
    SKIP_TTL = 1.day
    MESSAGE_FRAGMENT = "NOT PART OF CHAIN"
    PAGE_ID_IN_QUERY = /\bpage_id:\s*(\d+)/

    class << self
      def skip_page?(page_id)
        return false if page_id.blank?

        Rails.cache.exist?(cache_key(page_id))
      end

      def flag_page!(page_id, error: nil)
        return if page_id.blank?

        key = cache_key(page_id)
        already_flagged = Rails.cache.exist?(key)
        Rails.cache.write(key, true, expires_in: SKIP_TTL)
        return if already_flagged

        detail = error&.message.to_s.truncate(500)
        Rails.logger.error(
          "[TraitBank::Corruption] Skipping Neo4j for page #{page_id} for #{SKIP_TTL.inspect}: #{detail}"
        )
      end

      def clear_page!(page_id)
        return if page_id.blank?

        Rails.cache.delete(cache_key(page_id))
      end

      def chain_corruption?(error)
        each_exception(error) do |ex|
          return true if ex.message.to_s.include?(MESSAGE_FRAGMENT)
        end
        false
      end

      # Soft-fail wrapper for page-scoped Neo4j work.
      def guard(page_id, fallback:)
        return fallback if skip_page?(page_id)

        yield
      rescue StandardError => e
        if chain_corruption?(e)
          flag_page!(page_id, error: e)
          fallback
        else
          raise
        end
      end

      def extract_page_id(query, params = {})
        from_params = params[:page_id] || params["page_id"]
        return from_params.to_i if from_params.present?

        match = query.to_s[PAGE_ID_IN_QUERY, 1]
        match&.to_i
      end

      def cache_key(page_id)
        "neo4j/corrupt/page/#{page_id}"
      end

      private

      def each_exception(error)
        seen = {}
        current = error
        while current && !seen[current.object_id]
          seen[current.object_id] = true
          yield current
          current = if current.respond_to?(:cause) && current.cause
            current.cause
          elsif current.respond_to?(:original) && current.original
            current.original
          end
        end
      end
    end
  end
end
