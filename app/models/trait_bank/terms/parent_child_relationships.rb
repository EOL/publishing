# TraitBank::Terms::ParentChildRelationships.fetch is probably what you came here to call.
class TraitBank
  class Terms
    class Relationships
      class << self
        delegate :connection, to: TraitBank
        delegate :query, to: TraitBank
        delegate :term, to: TraitBank

        def remove_all(type = nil)
          type ||= :parent_term
          query(%Q{MATCH (:Term)-[rel:#{type}]->(:Term) DELETE rel})
          remove_is_hidden_from_select if type == :synonym_of
        end

        def remove_is_hidden_from_select
          query(%Q{MATCH (term:Term { is_hidden_from_select: true }) SET term.is_hidden_from_select = false})
        end

        def is_hidden_from_select(curi)
          query(%Q{MATCH (term:Term { uri: '#{curi}' }) SET term.is_hidden_from_select = true})
        end

        def current
          res = query(%Q{MATCH (child:Term)-[:parent_term]->(parent:Term) RETURN parent.uri, child.uri})
          # NOTE: the order of the returns is PARENT first, CHILD second.
          res["data"]
        end

        def fetch_parent_child_relationships(log = nil)
          # TODO: Don't hard-code this.
          link = 'https://opendata.eol.org/dataset/237b69b7-8aba-4cc4-8223-c433d700a1cc/'\
            'resource/f8036c30-f4ab-4796-8705-f3ccd20eb7e9/download/parent-child.csv'
          reload(download_csv(link), :child_has_parent, log: log, type: :parent_term)
        end

        def fetch_synonyms(log = nil)
          # TODO: Don't hard-code this.
          link = 'https://opendata.eol.org/dataset/237b69b7-8aba-4cc4-8223-c433d700a1cc/resource/'\
            '41f7fed1-3dc1-44d7-bbe5-6104156d1c1e/download/preferredsynonym.csv'
          reload(download_csv(link), :is_synonym_of, log: log, type: :synonym_of)
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

        def reload(pairs, fn, options = nil)
          log = options[:log]
          pairs.each do |pair|
            raise "The pairs must ALL be of exactly length 2. Aborting." unless pair.size == 2
            pair.each do |uri|
              raise "This doesn't look like a URI to me: #{uri} ...ABORTING." unless
                uri =~ URI::ABS_URI && Regexp.last_match.begin(0).zero?
            end
          end
          remove_all(options[:type])
          count = 0
          pairs.each do |pair|
            begin
              # NOTE: parent first, child second...
              TraitBank.send(fn, pair.last, pair.first)
              is_hidden_from_select(pair.last) if fn == :child_has_parent
              count += 1
            rescue => e
              # NOTE: the order here again is what the USER expects, not what the code called. :)
              message = "** WARNING: failed (#{pair.first},#{pair.last}) because #{e.message}"
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
