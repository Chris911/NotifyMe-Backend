require 'snoo'

module NotifyMe
  class Reddit

    def reddit
      @reddit_client ||= Snoo::Client.new
    end

    def cache
      requests = NotifyMe::requests_coll.find("service" => "reddit").to_a

      requests.each do |request|
        if request['type'] === 'reddit-front-page'
          front_page = reddit.get_listing

          File.open("/home/vagrant/notifyme/NotifyMe-Backend/cache/reddit/frontpage.json", "w") do |f|
            f.write(JSON.pretty_unparse(front_page))
          end

          #puts JSON.pretty_unparse(front_page)
          #front_page['data']['children'].each do |submission|
          #  puts submission['data']['title'] + " " + submission['data']['ups'].to_s
          #end
        end # End reddit-front-page
      end
    end
  end
end