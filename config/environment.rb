# This is meant to run initializers. ONLY. You probably don't want to change
# this file.

# Load the Rails application.
require File.expand_path('../application', __FILE__)
ENV['database_pass'] = 'pDy013UEjn7vU9zul'
ENV['schedular_ip'] = 'http://172.16.0.161:80/scheduler'
ENV['storage_ip'] = 'http://172.16.0.99:80/eol/archiver'
# Initialize the Rails application.
Rails.application.initialize!
DYNAMIC_HIERARCHY_RESOURCE_ID = 1
HBASE_ADDRESS = "http://172.16.0.99/hbase/api/"
HBASE_GET_LATEST_UPDATES_ACTION = "getLatestUpdates"

