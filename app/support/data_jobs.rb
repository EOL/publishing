# Wrapper for DelayedJob.
class DataJobs
  class << self
    def all
      Delayed::Job.where(queue: 'download')
    end

    def admin
      Delayed::Job.where(queue: 'download').
        select { |j| Delayed::Job.where(queue: 'download').last.payload_object.object.user_id == 1 }
    end

    def stop_admin
      admin.destroy_all
    end
  end
end
