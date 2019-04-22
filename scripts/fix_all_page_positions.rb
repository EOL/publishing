batch_size = 1000
start_page_id = 0

if ARGV.any?
  start_page_id = Integer(ARGV[0])
  puts "Starting with page id #{start_page_id} from input"
else
  puts "No page id provided -- starting from the beginning"
end

Page.find_in_batches(start: start_page_id, batch_size: batch_size).with_index do |pages, batch|
  resume_page = pages.first&.id
  puts "Processing batch #{batch} (pass page id #{resume_page} to script to resume here)"

  pages.each do |page|
    PageContent.fix_duplicate_positions(page.id)
  end
end

puts "Done!"

