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
  end
end