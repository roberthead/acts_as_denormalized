ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] = File.dirname(__FILE__) + '/rails_app'

require 'test/unit'
require 'rails_app/config/environment'

require '../lib/acts_as_denormalized'

$:.unshift File.dirname(__FILE__)

# config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
# ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
# 
# ActiveRecord::Base.establish_connection(config[db_adapter])
# 
# load(File.dirname(__FILE__) + "/schema.rb")
# require File.dirname(__FILE__) + '/../init.rb'
