class ApiReconciliationController < ApplicationController
  ManifestType = Struct.new(:name, :description)
  MANIFEST_TYPES = [
    ManifestType.new("page", "A representation of a taxon on EOL")
  ]

  # Service manifest
  def index
    @types = MANIFEST_TYPES
    render formats: :json
  end
end
