module TraitBank::PageDownloadWriter
  def self.to_arrays(hashes)
    pages = Page.where(:id => TraitBank::DownloadUtils.page_ids(hashes)).
      includes(:native_node, :preferred_vernaculars)
    data = []
    data << cols.keys
    hashes.each do |result|
      page_id = TraitBank::DownloadUtils.page_id(result)
      page = pages.find { |p| p.id == page_id }
      next if !page
      sci_name = page.native_node.scientific_names.where(:is_preferred => true).first # TODO: fix this hack
      row = []
      self.cols.each do |_, lamb|
        row << lamb[page, sci_name]
      end
      data << row
    end

    data
  end

  def self.cols
    {
      "Taxon URL" => -> (page, sci_name) { TraitBank::DownloadUtils.url(:page_url, page.id) },
      "Ancestry" => -> (page, sci_name) { TraitBank::DownloadUtils.ancestry(page) },
      "Scientific Name" => -> (page, sci_name) { sci_name&.canonical_form },
      "Common Name" => -> (page, sci_name) { page.name === page.scientific_name ? nil : page.name },
      "Author Name" => -> (page, sci_name) { sci_name&.authorship }
    }
  end

  def self.write(hashes, base_filename, url)
    arrays = self.to_arrays(hashes)
    path = TraitBank::DataDownload.path.join("pages_#{base_filename}.tsv")

    CSV.open(path, "wb", :col_sep => "\t") do |csv|
      arrays.each { |row| csv << row }
    end

    path
  end
end
