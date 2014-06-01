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
        elsif request['type'] === 'user-submission'
          user = request['username']
          last_id = request['last_id']
          if last_id == 'none'
            write_file(cache_dir, "#{user}_submission.json", "")
          else
            opts = {:type => 'submitted', :sort => 'new', :limit => '100', :before => last_id}
            comments = reddit.get_user_listing user, opts
            write_file(cache_dir, "#{user}_submission.json", JSON.pretty_unparse(comments))
          end
        elsif request['type'] === 'subreddit-alert'
          subreddit = request['subreddit']
          last_id = request['last_id']
          if last_id == 'none'
            write_file(cache_dir, "#{subreddit}_listing.json", "")
          else
            opts = {:subreddit => subreddit, :sort => 'new', :limit => '100', :before => last_id}
            links = reddit.get_listing opts
            write_file(cache_dir, "#{subreddit}_listing.json", JSON.pretty_unparse(links))
          end
        end
      end
    end

    # Returns the thing id of the last comment/submission with limit in days
    # Eg. last_comment(user, 2, comments) will return the last comment that it at most 2 days old.
    # Type should be either 'comments' or 'submitted'
    def last_thing_user(user, limit, type)
      limit = days_ago(limit).to_i
      opts = {:type => type, :sort => 'new', :limit => '100'}
      things = reddit.get_user_listing user, opts
      last_id = nil
      things['data']['children'].each do |thing|
        time = thing['data']['created']
        if time < limit
          return thing['data']['name']
        end
      end
      last_id
    end

    def last_thing_listing(subreddit, limit)
      limit = days_ago(limit).to_i
      opts = {:subreddit => subreddit, :sort => 'new', :limit => '100'}
      things = reddit.get_listing opts
      last_id = nil
      things['data']['children'].each do |thing|
        next if thing['data']['stickied']
        time = thing['data']['created']
        if time < limit
          return thing['data']['name']
        end
      end
      last_id
    end

    def set_last_comment
      requests = NotifyMe::requests_coll.find("service" => "reddit", "type" => "user-comment").to_a
      return if requests.empty?

      requests.each do |request|
        user = request['username']
        last_id = last_thing_user(user, 2, 'comments')
        last_id = 'none' if last_id.nil?
        NotifyMe::requests_coll.update({username: user},
              {
                  "$set" => {
                      last_id: last_id,
                  }
              })
      end
    end

    def set_last_submission
      requests = NotifyMe::requests_coll.find("service" => "reddit", "type" => "user-submission").to_a
      return if requests.empty?

      requests.each do |request|
        user = request['username']
        last_id = last_thing_user(user, 2, 'submitted')
        last_id = 'none' if last_id.nil?
        NotifyMe::requests_coll.update({username: user},
               {
                   "$set" => {
                       last_id: last_id,
                   }
               })
      end
    end

    def set_last_listing
      requests = NotifyMe::requests_coll.find("service" => "reddit", "type" => "subreddit-alert").to_a
      return if requests.empty?

      requests.each do |request|
        subreddit = request['subreddit']
        last_id = last_thing_listing(subreddit, 2)
        last_id = 'none' if last_id.nil?
        NotifyMe::requests_coll.update({subreddit: subreddit},
               {
                   "$set" => {
                       last_id: last_id,
                   }
               })
      end
    end

    def get_comment_permalink(comment)
      link_id = comment['data']['link_id']
      link_id.slice!(0..2)
      id = comment['data']['id']
      "http://www.reddit.com/comments/#{link_id}/_/#{id}"
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
        ids_sent = ids_sent_today notification
        comments.delete_if {|comment| ids_sent.include? comment['data']['id']} unless ids_sent.nil? or ids_sent.empty?
        next if comments.empty?

        ids = comments.map { |comment| comment['data']['id'] }

        message = "One of your comments has over #{score} upvotes"
        message = "Multiple of your comments have over #{score} upvotes" if comments.count > 1

        link = "http://reddit.com/user/#{user}"
        link = get_comment_permalink comments[0] if comments.count == 1

        body = {
            message: message,
            link: link,
            count: comments.count.to_s,
            type: "user-comment",
            service: "Reddit"
        }
        send_android_push(android_regIds, body)
        log_notification(notification, ids, message)
      end
    end

    def check_reddit_user_submission
      notifications = NotifyMe::notifications_coll.find("service" => "reddit",
                                                        "type" => "user-submission").to_a
      notifications.each do |notification|
        devices = get_devices notification['uid']
        next if devices.nil? or devices.empty?
        devices.flatten!
        android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
        next if android_regIds.empty?

        user = notification['username']
        score = notification['score']
        unless File.exist?(cache_dir + "#{user}_submission.json")
          self.cache
        end
        submissions = JSON.parse(read_file(cache_dir, "#{user}_submission.json"))
        next if submissions.empty?
        submissions = submissions['data']['children']
        submissions.select! { |submission| submission['data']['ups'] >= score }
        next if submissions.empty?
        ids_sent = ids_sent_today notification
        submissions.delete_if {|submission| ids_sent.include? submission['data']['id']} unless ids_sent.nil? or ids_sent.empty?
        next if submissions.empty?

        ids = submissions.map { |submission| submission['data']['id'] }

        message = "One of your submissions has over #{score} upvotes"
        message = "Multiple of your submissions have over #{score} upvotes" if submissions.count > 1

        link = "http://reddit.com/user/#{user}"
        link = "http://reddit.com#{submissions[0]['data']['permalink']}" if submissions.count == 1

        body = {
            message: message,
            link: link,
            count: submissions.count.to_s,
            type: "user-submission",
            service: "Reddit"
        }
        send_android_push(android_regIds, body)
        log_notification(notification, ids, message)
      end
    end

    def check_reddit_subreddit_alert
      notifications = NotifyMe::notifications_coll.find("service" => "reddit",
                                                        "type" => "subreddit-alert").to_a
      notifications.each do |notification|
        devices = get_devices notification['uid']
        next if devices.nil? or devices.empty?
        devices.flatten!
        android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
        next if android_regIds.empty?

        subreddit = notification['subreddit']
        score = notification['score']
        unless File.exist?(cache_dir + "#{subreddit}_listing.json")
          self.cache
        end
        links = JSON.parse(read_file(cache_dir, "#{subreddit}_listing.json"))
        next if links.empty?
        links = links['data']['children']
        links.select! { |link| link['data']['ups'] >= score }
        next if links.empty?
        ids_sent = ids_sent_today notification
        links.delete_if {|link| ids_sent.include? link['data']['id']} unless ids_sent.nil? or ids_sent.empty?
        next if links.empty?

        ids = links.map { |link| link['data']['id'] }

        message = "A submission on #{subreddit} has over #{score} upvotes"
        message = "Multiple submissions on #{subreddit} have over #{score} upvotes" if links.count > 1

        link = "http://reddit.com/r/#{subreddit}"
        link = "http://reddit.com#{links[0]['data']['permalink']}" if links.count == 1
        body = {
            message: message,
            link: link,
            count: links.count.to_s,
            type: "subreddit-alert",
            service: "Reddit"
        }
        send_android_push(android_regIds, body)
        log_notification(notification, ids, message)
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

        ids = posts.map {|post| post['data']['id']}
        ids_sent = ids_sent_today notification
        posts.delete_if {|comment| ids_sent.include? comment['data']['id']} unless ids_sent.nil? or ids_sent.empty?
        next if posts.empty?

        post_to_send = posts.map {|post| {title: post['data']['title'], url: "http://reddit.com#{post['data']['permalink']}"}}

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
        log_notification(notification, ids, message)
      end
    end

    def log_notification(notification, ids, message)
      notification.delete('_id')
      notification['time'] = Time.new.utc
      notification['message'] = message
      notification['ids'] = ids
      NotifyMe::logs_coll.insert(notification)
    end

    def ids_sent_today(notification)
      logs = NotifyMe::logs_coll.find({
              time: {"$gte" => days_ago(2),
                     "$lt" => tomorrow},
              uid: notification['uid'],
              service: notification['service'],
              type: notification['type'],
              score: notification['score']
          })
      ids = logs.map {|log| log['ids']}
      ids.uniq!
      ids.flatten! unless ids.nil?
      ids
    end

  end
end