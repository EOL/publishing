module TraitBank::PageDownloadWriter
  def self.to_arrays(hashes, url)
    data = []
    TraitBank::DownloadUtils.page_ids(hashes).in_groups_of(10_000) do |page_ids|
      pages = Page.with_name.where(:id => page_ids).collect { |p| [p.id, p] }.to_h
      data << (cols.keys << url)
      hashes.each do |result|
        page_id = TraitBank::DownloadUtils.page_id(result)
        page = pages[page_id]
        next if !page
        self.cols.each do |_, lamb|
          row << lamb[page]
        end
        data << row
      end
    end
    data
  end

  def self.cols
    {
      "Taxon URL" => -> (page) { TraitBank::DownloadUtils.resource_path(:page, page.id) },
      "Ancestry" => -> (page) { TraitBank::DownloadUtils.ancestry(page) },
      "Scientific Name" => -> (page) { page.scientific_name },
      "Common Name" => -> (page) { page.name === page.scientific_name ? nil : page.name },
      "Author Name" => -> (page) { sci_name&.authorship }
    }
  end

  def self.write(hashes, base_filename, url)
    arrays = self.to_arrays(hashes, url)
    filename = "pages_#{base_filename}.tsv"
    path = TraitBank::DataDownload.path.join(filename)

    CSV.open(path, "wb", :col_sep => "\t") do |csv|
      arrays.each { |row| csv << row }
    end

    filename
  end
end
