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
        message = "Minimum weather tomorrow in #{city.capitalize}: #{minimum}"
        body = {
            message: message,
            type: "minimum",
            service: "weather"
        }
        send_android_push(android_regIds, body)
      end
    end
  end


  end
end
