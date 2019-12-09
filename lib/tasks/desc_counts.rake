namespace :desc_counts do
  desc 'Calculates page descendant counts for auto-gen text and writes them to the db.'
  task :generate => :environment do
    Page::DescInfo.refresh
  end
end
