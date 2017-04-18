namespace :stats do
  desc "TODO"
  task richness: :environment do
    # Ha! This is a horrible way to do this. ...But I'm in a rush.
    scores = Hash.new(0)
    examples = {}
    count = 0
    puts "#{Page.count} pages"
    Page.find_each do |page|
      band = page.richness / 500
      if scores[band] == 0
        examples[band] = page
      end
      scores[band] += 1
      count += 1
      print "." if count % 1000 == 0
    end
    puts "\nScores:"
    (0..19).each do |band|
      print "  #{band * 5} - #{(band + 1) * 5 - 1}: #{scores[band]}"
      print "  e.g.: #{examples[band].id} (#{examples[band].name})" if examples.has_key?(band)
      print "\n"
    end
  end

  task score_richness: :environment do
    puts "#{Page.count} pages"
    count = 0
    Page.find_each do |page|
      page.score_richness
      score = page.richness
      count += 1
      print "." if count % 1000 == 0
    end
    puts "\nDone."
  end
end
