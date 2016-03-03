namespace :initial_users do
  desc 'create initial users'
  task :create_initial_users_list => :environment do
    visiting_time = Time.new(2015)
    #master curators
    5.times do |i|
      User.create name: "master curator #{i}", user_type: 'master_curator', address: "master curator #{i} address", visited_at: visiting_time
      visiting_time = visiting_time + 1.days
    end
    #full curators
    10.times do |i|
      User.create name: "full curator #{i}", user_type: 'full_curator', address: "full curator #{i} address", visited_at: visiting_time
      visiting_time = visiting_time + 1.days
    end
    #users
    20.times do |i|
      User.create name: "assistant curator #{i}", user_type: 'assistant_curator', address: "assistant curator #{i} address", visited_at: visiting_time
      visiting_time = visiting_time + 1.days
    end
    #users
    40.times do |i|
      User.create name: "user #{i}", user_type: 'user', address: "user #{i} address", visited_at: visiting_time 
      visiting_time = visiting_time + 1.days
    end
  end
end