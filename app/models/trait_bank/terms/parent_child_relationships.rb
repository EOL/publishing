# TraitBank::Terms::ParentChildRelationships.fetch is probably what you came here to call.
class TraitBank
  class Terms
    class ParentChildRelationships
      class << self
        delegate :child_has_parent, to: TraitBank
        delegate :connection, to: TraitBank
        delegate :query, to: TraitBank

        def remove_all
          query(%Q{MATCH (:Term)-[rel:parent_term]->(:Term) DELETE rel})
        end

        def current
          res = query(%Q{MATCH (child:Term)-[:parent_term]->(parent:Term) RETURN parent.uri, child.uri})
          # NOTE: the order of the returns is PARENT first, CHILD second.
          res["data"]
        end

        def fetch(log = nil)
          # TODO: Don't hard-code this.
          link = 'https://opendata.eol.org/dataset/237b69b7-8aba-4cc4-8223-c433d700a1cc/'\
            'resource/f8036c30-f4ab-4796-8705-f3ccd20eb7e9/download/parent-child.csv'
          reload(download_csv(link), log)
        end

        # TODO: truly, this does not belong in this class. :D
        def download_csv(link)
          require 'open-uri'
          raw =
            open(link, 'rb') do |input|
              input.read
            end
          # stip off the magic number that may be at the start:
          raw = raw.sub(/^[^h]+/i, '')
          lines = if raw.match?(/\r\n/m)
                    raw.split(/\r\n/)
                  elsif raw.match?(/\n/m)
                    raw.split(/\n/)
                  else
                    raw.split(/\r/)
                  end
          lines.map { |l| l.split(/,\s*/) }
        end

        def reload(pairs, log = nil)
          pairs.each do |pair|
            raise "The pairs must ALL be of exactly length 2. Aborting." unless pair.size == 2
            pair.each do |uri|
              raise "This doesn't look like a URI to me: #{uri} ...ABORTING." unless
                uri =~ URI::ABS_URI && Regexp.last_match.begin(0).zero?
            end
          end
          remove_all
          count = 0
          pairs.each do |pair|
            # NOTE: parent first, child second...
            begin
              child_has_parent(pair.last, pair.first)
              count += 1
            rescue => e
              message = "** WARNING: failed (#{pair.last},#{pair.first}) because #{e.message}"
              if log
                log << message
              else
                puts message
              end
            end
          end
          count
        end
      end
    end
  end
end
