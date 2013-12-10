require 'PolyNotify'

module NotifyMe
  class Poly
    include Utilities
    include Crypto

    def cache_dir
      NotifyMe::BASE_CACHE_DIR + "poly/result/"
    end

    def poly
      @poly ||= PolyNotify::Client.new
    end

    def check_results
      request = NotifyMe::requests_coll.find_one("service" => "poly")

      return if request.nil?

      credentials = request['credentials'].to_a
      credentials.each do |user|
        code = user['code']
        password = decrypt(user['password'], user['iv'])
        ddn = user['ddn']
        config = {"CODE" => code, "PASSWORD" => password, "DDN" => ddn}
        poly.load_config_hash config
        poly.log_in
        resultats = poly.get_resultats_finaux
        hash = get_last_results(code)
        if resultats != hash
          # New result available
          send_new_result(user['uid']) unless hash.empty?
          write_file(cache_dir, "#{code}.json", resultats)
        end
      end
    end

    def send_new_result(uid)
      notification = NotifyMe::notifications_coll.find_one("service" => "poly",
                                                            "type" => "result",
                                                            "uid" => uid)
      return if notification.nil?

      devices = get_devices notification['uid']
      devices.flatten!
      android_regIds = devices.collect {|device| device['regId'] if device['type'] == "android"}
      return if android_regIds.empty?

      body = {
          message: "Nouvelle note de disponible!",
          type: "result",
          service: "poly"
      }
      send_android_push(android_regIds, body)
      log_notification(notification)
    end

    def get_last_results(code)
      hash = ""
      if File.exist?(cache_dir + "#{code}.json")
        hash = read_file(cache_dir, "#{code}.json")
      end
      hash
    end

    def log_notification(notification)
      notification['time'] = Time.new.utc
      notification.delete('_id')
      NotifyMe::logs_coll.insert(notification)
    end
  end
end
