require "bundler/gem_tasks"

require_relative "lib/notifyMe"

task "cache_reddit-front-page" do
  desc "Cache Reddit front page"
  NotifyMe::Reddit.new.cache
end

task "notif_reddit-front-page" do
  desc "Check for notifications to send for Reddit front page"
  NotifyMe::Reddit.new.check_reddit_front_page
end