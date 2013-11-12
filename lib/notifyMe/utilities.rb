module NotifyMe
  module Utilities
    include HTTParty

    # HTTParty get wrapper. This serves to clean up code, as well as throw webserver errors wherever needed
    #
    def get *args, &block
      response = HTTParty.get *args, &block
      raise WebserverError, response.code unless response.code == 200
      response
    end

    # HTTParty POST wrapper. This serves to clean up code, as well as throw webserver errors wherever needed
    #
    def post *args, &block
      response = HTTParty.post *args, &block
      raise WebserverError, response.code unless response.code == 200
      response
    end

    def write_file(dir, file, content)
      unless File.directory?(dir)
        FileUtils.mkdir_p(dir)
      end
      File.open(dir+file, 'w') do |f|
        f.write(content)
      end
    end

    def read_file(dir, file)
      File.read(dir+file)
    end

    def get_devices(uid)
      user = NotifyMe::users_coll.find_one("uid" => uid)
      raise UserNotFound, "Invalid user" unless user
      user['devices'].to_a
    end

    def send_android_push(regId, body)
      post('https://notifyme-push.azure-mobile.net/api/android',
           query: { regId: regId, body: body },
           headers: { "X-ZUMO-APPLICATION" => CONFIG['AZURE_API_SECRET'] }
      )
      puts "Android notification sent!"
    end
  end

  class UserNotFound < Exception
  end

  class WebserverError < Exception
  end
end