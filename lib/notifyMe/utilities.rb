module NotifyMe
  module Utilities

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

    def get_devices(user)
      user = NotifyMe::users_coll.find_one("username" => user)
      raise UserNotFound, "Invalid user" unless user
      user['devices'].to_a
    end
  end

  class UserNotFound < Exception
  end
end