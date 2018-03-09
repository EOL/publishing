class Time
  def self.delta_str(start_time)
    took = Time.now - start_time
    if took < 90
      took = "#{took}s"
    elsif took < (90 * 60)
      took = "#{(took / 60.0).round(1)}m"
    elsif took < (48 * 60 * 60)
      took = "#{(took / (60 * 60.0)).round(1)}h"
    else
      took = "#{(took / (24 * 60 * 60.0)).round(1)}d"
    end
    took
  end
end
