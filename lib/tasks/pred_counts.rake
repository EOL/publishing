namespace :pred_counts do
  desc 'Generates data file for predicate wordcloud'
  task :generate => :environment do
    TbWordcloudData.generate_file
  end
end

