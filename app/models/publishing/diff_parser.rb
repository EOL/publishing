# Simple state machine to handle parsing diff file and resulting CRUD. Use attr_reader variables after running #parse.
# Sample diff:
# 10c10
# < blah blah
# ---
# > blah blah blah
# 15d14
# < blah blah
# 16a16
# > blah blah

class Publishing
  class DiffParser
    attr_reader :updated_from, :updated_to, :created, :deleted

    def initialize(params)
      @filename = params[:filename]
      @klass = params[:klass]
      @state = nil
      @updated_from = []
      @updated_to = []
      @created = []
      @deleted = []
      @update_reading = nil
      @create_re = /^(\d+)a(\d+)/
      @update_re = /^(\d+)c(\d+)/
      @delete_re = /^(\d+)d(\d+)/
      @update_midpoint_re = /^---/
      @in_line  = 0 # NOTE: I'm not actually using these now, but ... I might, if error-checking is required.
      @out_line = 0
    end

    def parse
      File.open(@filename, 'r').each_line do |line|
        next if state_changed?(line)
        line_data = line[2..-1]
        if @state == :create
          fail_unless_out(line)
          @created << line_data
        elsif @state == :update
          if @update_reading
            if line =~ @update_midpoint_re
              @update_reading = false
              next
            else
              fail_unless_in(line)
              @updated_from << line_data
            end
          else
            fail_unless_out(line)
            @updated_to << line_data
          end
        elsif @state == :delete
          fail_unless_in(line)
          @deleted << line_data
        else
          raise "Unhandled state: #{@state}"
        end
      end
    end

    def state_changed?(line)
      if m = line.match(@create_re)
        @state = :create
        @in_line = m[1]
        @out_line = m[2]
      elsif m = line.match(@update_re)
        @state = :update
        @update_reading = true
        @in_line = m[1]
        @out_line = m[2]
      elsif m = line.match(@delete_re)
        @state = :delete
        @in_line = m[1]
        @out_line = m[2]
      else # Some actual data, handle it:
        return false
      end
      true
    end

    def fail_unless_in(line)
      raise "Illegal diff direction (expected <): #{line}" unless line =~ /^< /
    end

    def fail_unless_out(line)
      raise "Illegal diff direction (expected >): #{line}" unless line =~ /^> /
    end
  end
end
