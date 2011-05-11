class Comment < ActiveRecord::Base
  
  include ActiveRecord::Acts::Denormalized

  belongs_to :post
  
end
