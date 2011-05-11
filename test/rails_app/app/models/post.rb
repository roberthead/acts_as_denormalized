class Post < ActiveRecord::Base

  include ActiveRecord::Acts::Denormalized

  acts_as_denormalized( {
    :on_changes_to_attributes => {
      :denormalized_user_name => [:user],
      :denormalized_comments_count => [:comments],
      :denormalized_identical_post_count => :always,
    },
    :denormalized_attributes_invalid_when_nil => [:denormalized_body_length]
  } )
  
  # named_scope :with_unset_denormalized_values, :conditions => Post.with_unset_denormalized_values_conditions
  
  belongs_to :user
  has_many :comments
  
  def compute_denormalized_user_name
    self.user.name rescue nil
  end
  
  def compute_denormalized_comments_count
    self.comments.length
  end
  
  def compute_denormalized_body_length
    self.body.length rescue nil
  end
  
  def compute_denormalized_identical_post_count
    if new_record?
      Post.count("subject LIKE \"#{self.subject}\" AND body LIKE \"#{self.body}\" AND user_id = #{self.user_id}")
    else
      Post.count("subject LIKE '#{self.subject}' AND body LIKE '#{self.body}' AND user_id = #{self.user_id} AND id != #{self.id}")
    end
  end
  
end
