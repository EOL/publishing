# This is meant to run initializers. ONLY. You probably don't want to change
# this file.

# Load the Rails application.
require File.expand_path('../application', __FILE__)

ENV['EOL_DB_DEVEL_USERNAME']= "root"
ENV['EOL_DB_DEVEL_PASSWORD'] = "Luxor&Aswan@2o17"


# Initialize the Rails application.
Rails.application.initialize!

DYNAMIC_HIERARCHY_RESOURCE_ID = 1
HBASE_ADDRESS = "http://172.16.0.99/hbase/api/"
HBASE_GET_LATEST_UPDATES_ACTION = "getLatestUpdates"
STORAGE_LAYER_IP= "172.16.0.99"

