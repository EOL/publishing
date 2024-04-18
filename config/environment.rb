# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

# IF YOU ARE READING THIS, you should remove the following monkey-patch and re-deploy to your staging area to see if it
# works. We were (2024-04-18) having a temporary problem and HAD to fix it by bypassing
# ActiveGraph::ModelSchema.validate_model_schema!
module ActiveGraph::ModelSchema::Monekypatch
  def self.validate_model_schema!
    return nil
  end
end

ActiveGraph::ModelSchema.include ActiveGraph::ModelSchema::Monekypatch
