# Wrapper for DelayedJob.
class DataJobs
  class << self
    def all
      Delayed::Job.where(queue: 'download')
    end

    def admin
      Delayed::Job.where(queue: 'download').select { |j| j.payload_object.object.user_id == 1 }
    end

    def stop_admin
      admin.map { |j| j.destroy }
    end

    def cure_zombie(job)
      job.locked_at = nil
      job.run_at = nil
      job.failed_at = nil
      job.locked_by = nil
      job.save
    end

    def pid
      `ps auxww | grep worker.start | grep download | grep -v grep | awk '{print $2}'`.chomp
    end

    def kill_worker
      process_id = pid
      `kill #{process_id}`
      sleep(4)
      `kill -9 #{process_id}` if process_id == pid
    end

    def delete_admin_processing
      UserDownload.where(user_id: 1, status: :created).where.not(processing_since: nil).delete_all
    end
  end
end
