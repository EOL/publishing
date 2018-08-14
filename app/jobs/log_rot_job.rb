class LogRotJob < ActiveJob::Base
  def perform
    `logrotate #{Rails.root.join('config', 'logrotate.conf')}`
  end
end
