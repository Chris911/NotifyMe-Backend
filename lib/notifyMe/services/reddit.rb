require 'mongo'
require 'snoo'

include Mongo

mongo_client = MongoClient.new.db("NotifyMe")
requests_coll = mongo_client.collection("requests")

requests = requests_coll.find("type" => "reddit").to_a
requests.each do |request|
  puts request['request']
end