module TraitBank::PageDownloadWriter
  def self.to_arrays(hashes, url)
    all_pages = Page.where(:id => TraitBank::DownloadUtils.page_ids(hashes)).
      includes(:preferred_scientific_names, :preferred_vernaculars)
    data = []
    all_pages.find_in_batches do |pages|
      data << (cols.keys << url)
      hashes.each do |result|
        page_id = TraitBank::DownloadUtils.page_id(result)
        page = pages.find { |p| p.id == page_id }
        # NOTE: this is not terribly efficient. :\ But because we're pulling the ID out using that
        # DownloadUtils.page_id, it's tricky (but not impossible... just ... ugly code) to group the hashes first. Note
        # that if we're in batches and this batch doesn't have your page, this w/b common. Luckily, this is a
        # *background* task, so should be ... okay.
        next if !page
        sci_name = page.preferred_scientific_names.first
        row = []
        self.cols.each do |_, lamb|
          row << lamb[page, sci_name]
        end
        data << row
      end
    end
    data
  end

  def self.cols
    {
      "Taxon URL" => -> (page, sci_name) { TraitBank::DownloadUtils.resource_path(:page, page.id) },
      "Ancestry" => -> (page, sci_name) { TraitBank::DownloadUtils.ancestry(page) },
      "Scientific Name" => -> (page, sci_name) { sci_name&.canonical_form },
      "Common Name" => -> (page, sci_name) { page.name === page.scientific_name ? nil : page.name },
      "Author Name" => -> (page, sci_name) { sci_name&.authorship }
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
