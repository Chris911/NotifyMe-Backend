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

      send_reddit_front_page(15000, over_15000) unless over_15000.empty?
      send_reddit_front_page(25000, over_25000) unless over_25000.empty?
      send_reddit_front_page(50000, over_50000) unless over_50000.empty?
    end

    def send_reddit_front_page(score, posts)
      notifications = NotifyMe::notifications_coll.find("service" => "reddit",
                                                        "type" => "reddit-front-page",
                                                        "score" => score.to_s).to_a
      return if notifications.empty?

      users = notifications.collect{|notif| notif['uid']}
      return if users.empty?

      devices = users.collect{ |uid|
        begin
          get_devices(uid)
        rescue UserNotFound
          puts "Invalid user: #{uid}"
        end
      }
      devices.flatten!
      android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
      return if android_regIds.empty?

      posts.map! {|post| {title: post['data']['title'], url: "http://reddit.com#{post['data']['permalink']}"}}

      message = "A post on reddit has over #{score} votes"
      message = "Multiple link on reddit with over #{score} votes" if posts.count > 1

      body = {
          message: message,
          count: posts.count.to_s,
          links: posts.to_json,
          type: "reddit-front-page",
          service: "Reddit"
      }

      send_android_push(android_regIds, body)
    end

    def log_notification(notification)

    end
  end
end