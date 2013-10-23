require 'snoo'

module NotifyMe
  class Reddit
    include Utilities

    def cache_dir
      NotifyMe::BASE_CACHE_DIR + "reddit/"
    end

    def reddit
      @reddit_client ||= Snoo::Client.new(:useragent => "NotifyMe Backend Service #{NotifyMe::VERSION}")
    end

    def cache
      requests = NotifyMe::requests_coll.find("service" => "reddit").to_a

      requests.each do |request|
        if request['type'] === 'reddit-front-page'
          front_page = reddit.get_listing
          write_file(cache_dir, "frontpage.json", JSON.pretty_unparse(front_page))
        end
      end
    end

    def check_reddit_front_page
      unless File.exist?(cache_dir + "frontpage.json")
        self.cache
      end
      front_page = JSON.parse(read_file(cache_dir, "frontpage.json"))
      over_15000 = front_page['data']['children'].select{|post| post['data']['ups'] >= 15000}
      over_25000 = front_page['data']['children'].select{|post| post['data']['ups'] >= 25000}
      over_50000 = front_page['data']['children'].select{|post| post['data']['ups'] >= 50000}

      send_reddit_front_page(15000, over_15000) if over_15000
      send_reddit_front_page(25000, over_15000) if over_25000
      send_reddit_front_page(50000, over_15000) if over_50000
    end

    def send_reddit_front_page(score, posts)
      notifications = NotifyMe::notifications_coll.find("service" => "reddit",
                                                        "type" => "reddit-front-page",
                                                        "score" => score.to_s).to_a
      users = notifications.collect{|notif| notif['user']}
      devices = users.collect{ |user|
        begin
          get_devices(user)
        rescue UserNotFound
          puts "Invalid user: #{user}"
        end
      }
      devices.flatten!
      # We can do better here..
      ios = devices.select{|device| device.to_s.include? "iOS"}
    end
  end
end