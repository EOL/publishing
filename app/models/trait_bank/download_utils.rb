module TraitBank::DownloadUtils
  def self.page_id(hash)
    hash[:page_id] || hash[:page] && hash[:page][:page_id]
  end

  def self.page_ids(hashes)
    hashes.map { |hash| self.page_id(hash) }.uniq.compact
  end

  def self.ancestry(page)
    return nil if page.nil?
    return nil if page.native_node.nil?
    page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ")
  end

  def self.resource_path(model_name, id)
    Rails.application.routes.url_helpers.send(
      "#{model_name}_path",
      :id => id
    )
  end
end
