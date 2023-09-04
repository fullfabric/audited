require 'mongo_mapper'

MongoMapper.connection = Mongo::Client.new(['127.0.0.1:27017'])
MongoMapper.database = 'audited_test'
