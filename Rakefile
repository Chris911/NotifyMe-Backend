require "bundler/gem_tasks"

require_relative "lib/notifyMe"

task :console do
  desc "Open an irb session preloaded with this library"
  sh "irb -rubygems -I lib -r notifyMe.rb"
end

task "cache_reddit" do
  desc "Cache Reddit infos"
  NotifyMe::Reddit.new.cache
end

task "notif_reddit-user-comment" do
  desc "Check for notifications to send for reddit user comment"
  NotifyMe::Reddit.new.check_reddit_user_comment
end

task "notif_reddit-user-submission" do
  desc "Check for notifications to send for reddit user submission"
  NotifyMe::Reddit.new.check_reddit_user_submission
end

task "notif_reddit-subreddit-alert" do
  desc "Check for notifications to send for reddit subreddit alert"
  NotifyMe::Reddit.new.check_reddit_subreddit_alert
end

task "set_last-comment" do
  desc "Set the last comment ID to check for"
  NotifyMe::Reddit.new.set_last_comment
end

task "set_last-submission" do
  desc "Set the last submission ID to check for"
  NotifyMe::Reddit.new.set_last_submission
end

task "set_last-listing" do
  desc "Set the last listing ID to check for"
  NotifyMe::Reddit.new.set_last_listing
end

task "notif_reddit-front-page" do
  desc "Check for notifications to send for Reddit front page"
  NotifyMe::Reddit.new.check_reddit_front_page
end

task "cache_weather-forecast" do
  desc "Cache the forecast for all cities"
  NotifyMe::Weather.new.cache
end

task "notif_weather" do
  desc "Send weather notification for all cities"
  NotifyMe::Weather.new.send_weather
end

task "notif_poly" do
  desc "Send poly notification for all users"
  NotifyMe::Poly.new.check_results
end

task "cache_github" do
  desc "Cache Github repo information"
  NotifyMe::Github.new.cache
end

task "notif_github-repo-watch" do
  desc "Send Github repo watch notifications"
  NotifyMe::Github.new.send_actions
end
