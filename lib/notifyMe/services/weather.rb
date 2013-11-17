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
          send_android_push(android_regIds, body)
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
          send_android_push(android_regIds, body)
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
        if weather.forecast_tomorrow_rain? city and notification['weather'] == 'rainy'
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
          send_android_push(android_regIds, body)
        end
      end
    end

  end
end
