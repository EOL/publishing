class LogRotJob < ApplicationJob
  def perform
    `/usr/sbin/logrotate #{Rails.root.join('config', 'logrotate.conf')} >> #{Rails.root.join('log', 'logrotate.log')} 2>&1`
  end
end
