# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, "logs/tasks.log"

every 25.minutes do
  rake "cache_reddit-front-page"
end

every 30.minutes do
  rake "notif_reddit-front-page"
end

every 3.hours do
  rake "cache_weather-forecast"
end

every 4.hours do
  rake "notif_weather"
end

every 30.minutes do
  rake "notif_poly"
end