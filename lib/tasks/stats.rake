def show_scores(scores, examples, count = 0)
  puts ".. Completed #{count}..." if count > 0
  puts "\nScores:"
  (0..19).each do |band|
    print "  #{band * 5} - #{(band + 1) * 5 - 1}: #{scores[band]}"
    print "  e.g.: #{examples[band].id} (#{examples[band].name})" if examples.has_key?(band)
    print "\n"
  end
  STDOUT.flush
end

namespace :stats do
  desc "TODO"
  task richness: :environment do
    puts "ONLY SCORING EMPTY VALUES" if ENV["BLANK"]
    pages = ENV["BLANK"] ? Page.where(page_richness: nil) : Page.where("id > 0")
    # Ha! This is a horrible way to do this. ...But I'm in a rush.
    scores = Hash.new(0)
    examples = {}
    count = 0
    puts "#{pages.count} pages"
    calc = RichnessScore.new
    pages.find_each do |page|
      score = calc.calculate(page)
      page.update_attribute(:page_richness, score)
      band = score / 500
      if scores[band] == 0
        examples[band] = page
      end
      scores[band] += 1
      count += 1
      show_scores(scores, examples, count) if count % 500 == 0
    end
    show_scores(scores, examples)
  end

  task score_richness: :environment do
    puts "#{Page.count} pages"
    start_time = Time.now
    count = 0
    Page.find_each do |page|
      page.score_richness
      score = page.richness
      count += 1
      print "." if count % 1000 == 0
    end
    puts "\nDone. Took #{((Time.now - start_time) / 1.minute).round} minutes."
  end
end
