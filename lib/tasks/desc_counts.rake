namespace :desc_counts do
  desc 'Generates data file for descendant count auto-gen text'
  task :generate => :environment do
    Page::Descendants.generate_counts_file
  end
end
