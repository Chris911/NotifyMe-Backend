# External require
require 'mongo'

$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

# Internal require
require 'notifyMe/version'
require 'notifyMe/utilities'
require 'notifyMe/services/reddit'

module NotifyMe
  include Mongo

  BASE_CACHE_DIR = "cache/"

  def self.db
    @mongo_client ||= MongoClient.new.db("NotifyMe")
  end

  def self.requests_coll
    @requests_coll ||= db.collection("requests")
  end

  def self.notifications_coll
    @notifications_coll ||= db.collection("notifications")
  end

  def self.users_coll
    @users_coll ||= db.collection("users")
  end
end
