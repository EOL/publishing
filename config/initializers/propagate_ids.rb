class ActiveRecord::Base
  class << self
    # I AM NOT A FAN OF SQL... but this is **way** more efficient than alternatives:
    def propagate_id(options = {})
      filter = options[:harvest_id] || options[:resource_id]
      filter_field =
        if filter
          # Harvest is more specific, prefer it:
          options[:harvest_id] ? :harvest_id : :resource_id
        end
      min = nil
      max = nil
      if filter
        min = where(filter_field => filter).minimum(:id)
        raise "None found!" if where(filter_field => filter).count.positive? if min.nil?
        max = where(filter_field => filter).maximum(:id)
      else
        min = minimum(:id)
        max = maximum(:id)
      end
      return nil if min.nil? || max.nil?
      fk = options[:fk]
      set = options[:set]
      with_field = options[:with]
      (o_table, o_field) = options[:other].split('.')
      update_clause  = "UPDATE `#{table_name}` t JOIN `#{o_table}` o ON (t.`#{fk}` = o.`#{o_field}`"
      update_clause += " AND t.#{filter_field} = ? AND o.#{filter_field} = t.#{filter_field}" if filter
      update_clause += ')'
      set_clause = "SET t.`#{set}` = o.`#{with_field}`"
      page_size = 100_000 # TODO: play around with this, find the ideal value. 10K seemed too small, ran in 300-600ms.
      if max - min > page_size
        range_clause = "WHERE t.#{primary_key} >= ? AND t.#{primary_key} <= ?"
        while max > min
          upper = min + page_size - 1
          if filter
            clean_execute([[update_clause, set_clause, range_clause].join(' '), filter, min, upper])
          else
            clean_execute([[update_clause, set_clause, range_clause].join(' '), min, upper])
          end
          min += page_size
        end
      else
        clean_execute([[update_clause, set_clause].join(' '), filter]) # NOTE: filter here can be nil and have no effect
      end
    end

    def clean_execute(args)
      clean_sql = sanitize_sql(args)
      connection.execute(clean_sql)
    end
  end
end
