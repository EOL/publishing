# This is meant to run initializers. ONLY. You probably don't want to change
# this file.

# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

DYNAMIC_HIERARCHY_RESOURCE_ID = 1
HBASE_ADDRESS = "http://172.16.0.99/hbase/api/"
HBASE_GET_LATEST_UPDATES_ACTION = "getLatestUpdates"
