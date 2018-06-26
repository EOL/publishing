module TraitBank::DownloadUtils
  def self.page_id(hash)
    hash[:page_id] || hash[:page] && hash[:page][:page_id]
  end

  def self.page_ids(hashes) 
    hashes.map { |hash| self.page_id(hash) }.uniq.compact
  end

  def self.ancestry(page)
    page ? page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ") : nil
  end

  # XXX: This is a hack-y way of getting the host, but I didn't want to mess with configs for this
  def self.url(helper_name, id)
    Rails.application.routes.url_helpers.send(
      helper_name,
      :id => id, 
      :host => Rails.application.config.action_mailer.default_url_options[:host]
    )
  end
end
