class User < ActiveRecord::Base
  
  include ActiveRecord::Acts::Denormalized

  has_many :posts
  
end
