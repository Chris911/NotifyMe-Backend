require 'octokit'

module NotifyMe
  class Github
    include Utilities

    def cache_dir
      NotifyMe::BASE_CACHE_DIR + "github/"
    end

    def cache
      requests = NotifyMe::requests_coll.find("service" => "github", "type" => "github-repo-watch").to_a

      requests.each do |request|
        info = get_info request['user'], request['repo']
        write_file(cache_dir, "#{request['user']}_#{request['repo']}.json", JSON.pretty_unparse(info))
      end
    end

    def get_info(user, repo)
      repo = Octokit.repo "#{user}/#{repo}"
      info = {"owner" => repo[:owner].login,
              "name" => repo[:name],
              "stars" => repo[:stargazers_count],
              "forks" => repo[:forks_count],
              "issues" => repo[:open_issues_count],
              "link" => "http://github.com/#{repo[:owner].login}/#{repo[:name]}"}
      JSON.parse info.to_json
    end

    def send_actions
      notifications = NotifyMe::notifications_coll.find("service" => "github",
                                                        "type" => "github-repo-watch").to_a
      return if notifications.empty?

      notifications.each do |notification|
        devices = get_devices notification['uid']
        devices.flatten!
        android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
        next if android_regIds.empty?

        user = notification['user']
        repo = notification['repo']
        action = notification['action']
        if File.exist?(cache_dir + "#{user}_#{repo}.json")
          info = get_info user, repo
          file_info = JSON.parse read_file(cache_dir, "#{user}_#{repo}.json")
          case action
            when 'stars'
              if info['stars'].to_i > file_info['stars'].to_i
                diff = info['stars'].to_i - file_info['stars'].to_i
                action = action[0..-2] if diff == 1
                message = "You have #{diff} new #{action} on your repo: #{info['name']}"
                send_notification(android_regIds, message, info)
                log_notification(notification, message)
              end
            when 'forks'
              if info['forks'].to_i > file_info['forks'].to_i
                diff = info['forks'].to_i - file_info['forks'].to_i
                action = action[0..-2] if diff == 1
                message = "You have #{diff} new #{action} on your repo: #{info['name']}"
                send_notification(android_regIds, message, info)
                log_notification(notification, message)
              end
            when 'issues'
              if info['issues'].to_i > file_info['issues'].to_i
                diff = info['issues'].to_i - file_info['issues'].to_i
                action = action[0..-2] if diff == 1
                message = "You have #{diff} new opened #{action} on your repo: #{info['name']}"
                send_notification(android_regIds, message, info)
                log_notification(notification, message)
              end
            else
              # Unknown action
          end
        end
      end
    end

    def send_notification(devices, message, info)
      body = {
          message: message,
          link: info['link'],
          type: "github-repo-watch",
          service: "github"
      }
      send_android_push(devices, body)
    end

    def log_notification(notification, message)
      notification['time'] = Time.new.utc
      notification['message'] = message
      notification.delete('_id')
      NotifyMe::logs_coll.insert(notification)
    end

  end
end
