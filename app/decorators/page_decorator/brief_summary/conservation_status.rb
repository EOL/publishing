class PageDecorator
  class BriefSummary
    class ConservationStatus
      attr_reader :page
      def initialize(page)
        @page = page
      end

      def by_provider
        if @by_provider
          return @by_provider
        end

        @by_provider = {}
        if page.grouped_data.has_key?(Eol::Uris::Conservation.status)
          recs = page.grouped_data[Eol::Uris::Conservation.status]
          multiples_warned = Set.new
          recs.each do |rec|
            uri = TraitBank::Record.obj_term_uri(rec)
            name = TraitBank::Record.obj_term_name(rec)
            source = TraitBank::Record.source(rec)
            resource_id = TraitBank::Record.resource_id(rec)

            next if resource_id.blank?

            provider = case resource_id
                       when Resource.iucn&.id
                         :iucn
                       when Resource.cosewic&.id
                         :cosewic
                       when Resource.cites&.id
                         :cites
                       #when Resource.usfw&.id
                       #  :usfw
                       else
                         Rails.logger.warn("Unable to classify conservation status uri by resource id: #{resource_id}")
                         nil
                       end

            if provider
              if @by_provider.include?(provider) && !multiples_warned.include?(provider)
                Rails.logger.warn("Found multiple conservation status traits for page #{page.id}/provider #{provider}")
                multiples_warned.add(provider)
              else
                @by_provider[provider] = {
                  object_term: rec[:object_term],
                  uri: uri,
                  name: name,
                  source: source
                }
              end
            end
          end
        end

        @by_provider
      end
    end
  end
end
