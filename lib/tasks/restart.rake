desc 'Restart the servers.'
task :restart do
  # OLD:
  # things = `ps -ef | grep "unicorn worker" | grep -v "color" | awk '{print $2;}'`
  # things.split("\n").each do |pid|
  #   puts pid
  #   `kill #{pid}`
  #   sleep(2)
  # end
  id = `cat tmp/unicorn.pid`.chomp
  `kill -USR2 #{id} ; sleep 2 ; kill -QUIT #{id}`
  # NOTE: 'restart' wasn't always working for me; this was.
  `service nginx stop`
  `service nginx start`
  res = `curl localhost:3000//`
  puts res.sub(/^.*<body/m, '<body')[0..640]
  puts "...etc..."
  puts "DONE."
end
