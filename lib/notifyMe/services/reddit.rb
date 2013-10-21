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
        end
      end
    end
  end
end