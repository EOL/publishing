desc 'Restart the servers.'
task :restart do
  things = `ps -ef | grep "unicorn worker" | grep -v "color" | awk '{print $2;}'`
  things.split("\n").each do |pid|
    puts pid
    `kill #{pid}`
    sleep(2)
  end
  res = `curl localhost:3000//`
  puts res.sub(/^.*<body/m, '<body')[0..640]
  puts "...etc..."
  puts "DONE."
end
