# TraitBank::Terms::Relationships.fetch_* are the methods you probably came here to call.
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
          log << "Starting parent/child term relationships fetch." if log
          # TODO: Don't hard-code this.
          link = "f8036c30-f4ab-4796-8705-f3ccd20eb7e9/download/parent-child-july8.csv"
          reload(download_csv(link), :child_has_parent, log: log, type: :parent_term)
        end

        def fetch_synonyms(log = nil)
          log << "Starting term synonyms fetch." if log
          # TODO: Don't hard-code this.
          link = "41f7fed1-3dc1-44d7-bbe5-6104156d1c1e/download/preferredsynonym.csv"
          reload(download_csv(link), :is_synonym_of, log: log, type: :synonym_of)
        end

        def fetch_units(log = nil)
          log << "Starting term units fetch." if log
          # TODO: Don't hard-code this.
          link = "d90b165f-92ad-44fe-aef2-ecd25721caac/download/defaultunits.csv"
          reload(download_csv(link), :set_units_for_pred, log: log, type: :units_term)
        end

        # TODO: truly, this does not belong in this class. :D
        def download_csv(link)
          require 'open-uri'
          # TODO: Don't hard-code this.
          opendata_dataset_path = 'https://opendata.eol.org/dataset/237b69b7-8aba-4cc4-8223-c433d700a1cc/'
          raw =
            open("#{opendata_dataset_path}resource/#{link}", 'rb') do |input|
              input.read.force_encoding(Encoding::ISO_8859_1)
            end
          lines = if raw.match?(/\r\n/m)
                    raw.split(/\r\n/)
                  elsif raw.match?(/\n/m)
                    raw.split(/\n/)
                  else
                    raw.split(/\r/)
                  end
          lines.first.sub!(/^\W+/, '') # Strip any magic number at the start of the file. This happens.
          lines.map { |l| l.split(/,\s*/) }
        end

        def reload(pairs, fn, options = nil)
          log = options[:log]
          pairs.each do |pair|
            raise "The pairs must ALL be of exactly length 2. Aborting. (#{pair.inspect})" unless pair.size == 2
            pair.each do |uri|
              next if uri == 'unitless' && fn == :set_units_for_pred && uri == pair[1]
              raise "This doesn't look like a URI to me: #{uri} ...ABORTING." unless
                # NOTE: It "feels" silly to escape the string and then test it for being a URI. ...But without it,
                # characters like mu (μ) fail this test, and really we're just testing it for the http:// and the like.
                URI.escape(uri) =~ URI::ABS_URI && Regexp.last_match.begin(0).zero?
            end
          end
          remove_all(options[:type])
          count = 0
          pairs.each do |pair|
            begin
              parent = clean_url(pair.first)
              child = clean_url(pair.last)
              TraitBank::Terms.send(fn, child, parent)
              is_hidden_from_select(child) if fn != :set_units_for_pred
              count += 1
            rescue => e
              # NOTE: the order here again is what the USER expects, not what the code called. :)
              message = "** WARNING: failed (#{parent},#{child}) because #{e.message}"
              if log
                log << message
              else
                puts message
              end
            end
          end
          count
        end

        def clean_url(url)
          url = url.sub(/\s+$/, '').sub(/^\s+/, '')
        end
      end
    end
  end
end
