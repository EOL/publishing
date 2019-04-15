Page.find_in_batches.with_index do |pages, batch|
  puts "Processing batch #{batch}"

  pages.each do |page|
    PageContent.fix_duplicate_positions(page.id)
  end
end

puts "Done!"

