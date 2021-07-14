module Reconciliation
  module TaxonEntityResolver
    ID_REGEX = /^pages\/(\d+)$/

    attr_accessor :page

    class << self
      def resolve_hash(entity_hash)
        return nil unless entity_hash.include?('id')
        
        id_str = entity_hash['id']
        return nil if id_str.blank?

        resolve_id(id_str)
      end

      def resolve_id(id)
        parsed_id = parse_id(id)
        return unless parsed_id

        Page.find_by(id: parsed_id)
      end

      def resolve_ids(ids, options = {})
        parsed_ids = ids.map do |id|
          raise ArgumentError, "ids can't contain nil value" if id.nil?

          [id, parse_id(id)]
        end.to_h

        page_includes = options[:includes] ? Page.includes(options[:includes]) : Page
        pages = page_includes.where(id: parsed_ids.values.compact).map { |p| [p.id, p] }.to_h

        parsed_ids.map do |k, v|
          [k, v.nil? ? nil : pages[v]]
        end.to_h
      end

      private
      def parse_id(id)
        return nil unless id.is_a?(String)

        ID_REGEX.match(id)&.[](1)&.to_i
      end
    end
  end
end
