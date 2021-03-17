module DataIntegrityCheck::ZeroCountCheck
  # including classes must implement query and build_count_message methods
 
  def run
    result = ActiveGraph::Base.query(query).to_a.first
    count = result[:count]
    status = count == 0 ? :passed : :failed
    message = build_count_message(count)

    DataIntegrityCheck::Result.new(status, message)
  end
end
