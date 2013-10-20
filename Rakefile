require "bundler/gem_tasks"

require_relative "lib/notifyMe"

task "reddit-front-page" do
  desc "Cache Reddit front page"
  NotifyMe::Reddit.new.cache()
end