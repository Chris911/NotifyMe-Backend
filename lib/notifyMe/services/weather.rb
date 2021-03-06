require 'OpenWeather'

module NotifyMe
  class Weather
    include Utilities

    def cache_dir
      NotifyMe::BASE_CACHE_DIR + "weather/"
    end

    def weather
      @weather ||= OpenWeather::Client.new
    end

    def cache
      request = NotifyMe::requests_coll.find_one("service" => "weather")

      cities = request['cities'].to_a
      cities.each do |city|
        forecast = weather.forecast_raw city
        write_file(cache_dir, "#{city}.json", JSON.pretty_unparse(forecast))
      end
    end

    def send_weather
      send_minimum
      send_maximum
      send_forecast
    end

    def send_minimum
      notifications = NotifyMe::notifications_coll.find("service" => "weather",
                                                        "type" => "minimum").to_a
      return if notifications.empty?

      notifications.each do |notification|
        city = notification['city']
        weather.load_file(cache_dir+city+".json") if File.exist?(cache_dir+city+".json")
        minimum = weather.forecast_tomorrow_min city
        if minimum <= notification['temperature']
          devices = get_devices notification['uid']
          devices.flatten!
          android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
          return if android_regIds.empty?

          city_name = weather.city_name_from_file
          city_name.empty? ?
              message = "Minimum temperature tomorrow: #{minimum}" :
              message = "Minimum temperature tomorrow in #{city_name.capitalize}: #{minimum}"
          body = {
              message: message,
              type: "minimum",
              service: "weather"
          }
          unless notification_sent_today? notification
            send_android_push(android_regIds, body)
            log_notification(notification, message)
          end
        end
      end
      weather.unload_file
    end

    def send_maximum
      notifications = NotifyMe::notifications_coll.find("service" => "weather",
                                                        "type" => "maximum").to_a
      return if notifications.empty?

      notifications.each do |notification|
        city = notification['city']
        weather.load_file(cache_dir+city+".json") if File.exist?(cache_dir+city+".json")
        maximum = weather.forecast_tomorrow_max city
        if maximum >= notification['temperature']
          devices = get_devices notification['uid']
          devices.flatten!
          android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}

          return if android_regIds.empty?

          city_name = weather.city_name_from_file
          city_name.empty? ?
              message = "Maximum temperature tomorrow: #{maximum}" :
              message = "Maximum temperature tomorrow in #{city_name.capitalize}: #{maximum}"
          body = {
              message: message,
              type: "maximum",
              service: "weather"
          }
          unless notification_sent_today? notification
            send_android_push(android_regIds, body)
            log_notification(notification, message)
          end
        end
      end
      weather.unload_file
    end

    def send_forecast
      notifications = NotifyMe::notifications_coll.find("service" => "weather",
                                                        "type" => "forecast").to_a
      return if notifications.empty?

      notifications.each do |notification|
        city = notification['city']
        weather.load_file(cache_dir+city+".json") if File.exist?(cache_dir+city+".json")
        if notification['weather'] == 'rainy' and weather.forecast_tomorrow_rain? city
          devices = get_devices notification['uid']
          devices.flatten!
          android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}

          return if android_regIds.empty?

          city_name = weather.city_name_from_file
          city_name.empty? ?
              message = "Looks like it will rain tomorrow." :
              message = "Looks like it will rain tomorrow in #{city_name.capitalize}"
          body = {
              message: message,
              type: "forecast",
              service: "weather"
          }
          unless notification_sent_today? notification
            send_android_push(android_regIds, body)
            log_notification(notification, message)
          end
        else if notification['weather'] == 'sunny' and weather.forecast_tomorrow_sunny? city
            devices = get_devices notification['uid']
            devices.flatten!
            android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}

            return if android_regIds.empty?

            city_name = weather.city_name_from_file
            city_name.empty? ?
                message = "Looks like it will be sunny tomorrow." :
                message = "Looks like it will be sunny tomorrow in #{city_name.capitalize}"
            body = {
                message: message,
                type: "forecast",
                service: "weather"
            }
            unless notification_sent_today? notification
              send_android_push(android_regIds, body)
              log_notification(notification, message)
            end
          end
        end
      end
    end

    def log_notification(notification, message)
      notification['time'] = Time.new.utc
      notification['message'] = message
      notification.delete('_id')
      NotifyMe::logs_coll.insert(notification)
    end

    # This will check if a notification was sent today for these filters
    # We get the logs with date greater than today and less than tomorrow
    # and check if the returned array is empty.
    def notification_sent_today?(notification)
      ! NotifyMe::logs_coll.find({
          time: {"$gte" => today,
                 "$lt" => tomorrow},
          uid: notification['uid'],
          service: notification['service'],
          type: notification['type'],
          city: notification['city']
      }).to_a.empty?
    end

  end
end
