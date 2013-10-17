require 'mongo'
require 'snoo'

include Mongo

mongo_client = MongoClient.new.db("NotifyMe")
requests_coll = mongo_client.collection("requests")
requests = requests_coll.find("service" => "reddit").to_a

reddit_client = Snoo::Client.new

requests.each do |request|
  if request['type'] === 'reddit-front-page'
    front_page = reddit_client.get_listing
    #puts JSON.pretty_unparse(front_page)

    front_page['data']['children'].each do |submission|
      puts submission['data']['title'] + " " + submission['data']['ups'].to_s
    end
  end
end