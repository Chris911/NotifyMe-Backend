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
        elsif request['type'] === 'user-comment'
          user = request['username']
          last_id = request['last_id']
          if last_id == 'none'
            write_file(cache_dir, "#{user}_comment.json", "")
          else
            opts = {:type => 'comments', :sort => 'new', :limit => '100', :before => last_id}
            comments = reddit.get_user_listing user, opts
            write_file(cache_dir, "#{user}_comment.json", JSON.pretty_unparse(comments))
          end
        end
      end
    end

    # Returns the thing id of the last comment with limit in days
    # Eg. last_comment(user, 2) will return the last comment that it at most 2 days old.
    def last_comment(user, limit)
      limit = days_ago(limit).to_i
      opts = {:type => 'comments', :sort => 'new', :limit => '100'}
      comments = reddit.get_user_listing user, opts
      last_id = nil
      comments['data']['children'].each do |comment|
        time = comment['data']['created']
        if time < limit
          return "t1_#{comment['data']['id']}"
        end
      end
      last_id
    end

    def set_last_comment
      requests = NotifyMe::requests_coll.find("service" => "reddit", "type" => "user-comment").to_a
      return if requests.empty?

      requests.each do |request|
        user = request['username']
        last_id = last_comment(user, 2)
        last_id = 'none' if last_id.nil?
        NotifyMe::requests_coll.update({username: user},
              {
                  "$set" => {
                      last_id: last_id,
                  }
              })
      end
    end

    def check_reddit_user_comment
      notifications = NotifyMe::notifications_coll.find("service" => "reddit",
                                                        "type" => "user-comment").to_a
      notifications.each do |notification|
        devices = get_devices notification['uid']
        next if devices.nil? or devices.empty?
        devices.flatten!
        android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
        next if android_regIds.empty?

        user = notification['username']
        score = notification['score']
        unless File.exist?(cache_dir + "#{user}_comment.json")
          self.cache
        end
        comments = JSON.parse(read_file(cache_dir, "#{user}_comment.json"))
        next if comments.empty?
        comments = comments['data']['children']
        comments.select! { |comment| comment['data']['ups'] >= score }
        next if comments.empty?
        message = "One of your comments has over #{score} upvotes"
        message = "Multiple of your comments have over #{score} upvotes" if comments.count > 1

        body = {
            message: message,
            count: comments.count.to_s,
            type: "user-comment",
            service: "Reddit"
        }
        send_android_push(android_regIds, body)
        #log_notification(notification, comments)
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

      notifications.each do |notification|
        devices = get_devices notification['uid']
        next if devices.nil? or devices.empty?
        devices.flatten!
        android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
        next if android_regIds.empty?

        post_to_send = posts.map {|post| {title: post['data']['title'], url: "http://reddit.com#{post['data']['permalink']}"}}

        sent_posts = links_sent_today notification
        post_to_send.delete_if {|post| sent_posts.include? post[:url]} unless sent_posts.nil? or sent_posts.empty?
        return if post_to_send.empty?

        message = "A post on reddit has over #{score} votes"
        message = "Multiple posts on reddit with over #{score} votes" if posts.count > 1

        body = {
            message: message,
            count: post_to_send.count.to_s,
            links: post_to_send.to_json,
            type: "reddit-front-page",
            service: "Reddit"
        }
        send_android_push(android_regIds, body)
        log_notification(notification, post_to_send)
      end
    end

    def log_notification(notification, links)
      notification.delete('_id')
      notification['time'] = Time.new.utc
      notification['links'] = links
      NotifyMe::logs_coll.insert(notification)
    end

    def links_sent_today(notification)
      logs = NotifyMe::logs_coll.find({
              time: {"$gte" => yesterday,
                     "$lt" => tomorrow},
              uid: notification['uid'],
              service: notification['service'],
              type: notification['type'],
              score: notification['score']
            })
      posts = logs.map {|log| log['links']}
      links = posts.map {|post| post.at(0)['url']}
      links.uniq!
      links
    end

  end
end