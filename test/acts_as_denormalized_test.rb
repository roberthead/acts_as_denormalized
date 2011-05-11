require 'test/unit'
require File.dirname(__FILE__) + '/test_helper.rb'

class ActsAsDenormalizedTest < Test::Unit::TestCase

  def setup
    @ogden = User.create!(:name => 'Ogden Nash')
    @poetry = Post.new(:subject => 'Further Reflections on Parsley', :body => "Parsley\nIs gharsley.", :user => @ogden)
  end
  
  def test_denormalized_attribute_prefix
    assert_equal("denormalized_", Post.denormalized_attribute_prefix)
  end
  
  def test_denormalized_compute_method_prefix
    assert_equal("compute_denormalized_", Post.denormalized_compute_method_prefix)
  end
  
  def test_acts_as_denormalized
    assert_equal('denormalized_', Post.denormalized_attribute_prefix)
    assert_equal('compute_denormalized_', Post.denormalized_compute_method_prefix)
    assert_equal(
      {
        :denormalized_user_name => [:user],
        :denormalized_comments_count => [:comments],
        :denormalized_identical_post_count => :always,
      },
      Post.denormalized_on_changes_to_attributes
    )
    assert_equal(
      [ :denormalized_body_length ],
      Post.denormalized_attributes_invalid_when_nil
    )
    assert Post.included_modules.include?(ActiveRecord::Acts::Denormalized::InstanceMethods)
    assert Post.new.respond_to?(:compute_denormalized_values)
    assert_nil(User.denormalized_attribute_prefix)
    assert_nil(User.denormalized_compute_method_prefix)
    assert User.denormalized_on_changes_to_attributes.blank?
    assert !User.included_modules.include?(ActiveRecord::Acts::Denormalized::InstanceMethods)
    assert !User.new.respond_to?(:compute_denormalized_values)
  end
  
  def test_denormalized_attribute_names
    assert_equal(
      [
        "denormalized_body_length",
        "denormalized_comments_count",
        "denormalized_identical_post_count",
        "denormalized_user_name"
      ].sort, Post.denormalized_attribute_names.sort)
  end
  
  def test_denormalization_timestamps
    assert_equal(
      [
        "denormalized_body_length_computed_at",
        "denormalized_comments_count_computed_at",
        "denormalized_user_name_computed_at"
      ].sort, Post.denormalization_timestamps.sort)
  end
  
  def test_corresponding_denormalization_timestamp
    assert_equal("denormalized_body_length_computed_at", Post.corresponding_denormalization_timestamp("denormalized_body_length"))
    assert_equal(nil, Post.corresponding_denormalization_timestamp("denormalized_identical_post_count"))
  end
  
  def test_corresponding_denormalization_timestamp?
    %w{denormalized_body_length denormalized_comments_count denormalized_user_name}.each do |field|
      assert Post.corresponding_denormalization_timestamp?(field)
    end
    assert !Post.corresponding_denormalization_timestamp?('denormalized_identical_post_count')
  end
  
  def test_denormalized_attribute_base_name
    assert_equal('user_name', Post.denormalized_attribute_base_name('denormalized_user_name'))
    assert_equal('user_name', Post.denormalized_attribute_base_name(:denormalized_user_name))
  end
  
  def test_denormalized_attribute_name_from_base_name
    assert_equal("denormalized_user_name", Post.denormalized_attribute_name_from_base_name('user_name'))
    assert_equal("denormalized_user_name", Post.denormalized_attribute_name_from_base_name(:user_name))
    assert_equal("denormalized_user_name", Post.denormalized_attribute_name_from_base_name(Post.denormalized_attribute_base_name('denormalized_user_name')))
    assert_equal("denormalized_user_name", Post.denormalized_attribute_name_from_base_name(Post.denormalized_attribute_base_name(:denormalized_user_name)))
  end
  
  def test_denormalized_compute_method_name
    assert_equal('compute_denormalized_user_name', Post.denormalized_compute_method_name('denormalized_user_name'))
    assert_equal('compute_denormalized_user_name', Post.denormalized_compute_method_name(:denormalized_user_name))
  end
  
  def test_denormalized_attribute?
    assert Post.denormalized_attribute?('denormalized_user_name')
    assert Post.denormalized_attribute?(:denormalized_user_name)
    assert !Post.denormalized_attribute?('id')
    assert !Post.denormalized_attribute?(:subject)
    assert !Post.denormalized_attribute?('user_id')
  end
  
  def test_unset_denormalized_value
    @poetry.save
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
    assert @poetry.denormalized_user_name_computed_at >= 1.second.ago
    @poetry.unset_denormalized_value('denormalized_user_name')
    assert_equal(nil, @poetry.denormalized_user_name)
    assert_equal(nil, @poetry.denormalized_user_name_computed_at)
  end
  
  def test_compute_denormalized_values_by_sql
    @poetry.save
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
    assert @poetry.denormalized_user_name_computed_at >= 1.second.ago
    @poetry.unset_denormalized_value('denormalized_user_name')
    assert_equal(nil, @poetry.denormalized_user_name)
    assert_equal(nil, @poetry.denormalized_user_name_computed_at)
    @poetry.compute_denormalized_values_by_sql
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
    assert @poetry.denormalized_user_name_computed_at >= 1.second.ago
    @poetry.reload
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
    assert @poetry.denormalized_user_name_computed_at >= 1.second.ago
  end
  
  def test_save_computes_denormalized_values
    assert_equal(nil, @poetry.denormalized_user_name)
    @poetry.save
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
    @poetry.unset_denormalized_value('denormalized_user_name')
    assert_equal(nil, @poetry.denormalized_user_name)
    assert_equal(nil, @poetry.denormalized_user_name_computed_at)
    @poetry.save
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
  end
  
  def test_denormalized_value_stale?
    assert @poetry.changed?
    assert @poetry.denormalized_value_stale?('denormalized_user_name')
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.save
    assert !@poetry.changed?
    assert !@poetry.denormalized_value_stale?('denormalized_user_name')
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.user = User.create(:name => 'some other guy')
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.save
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.user.name = "fred"
    assert @poetry.user.changed?
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.user.save
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.save
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
    Post.update_all('denormalized_user_name = NULL', "id = #{@poetry.id}")
    @poetry.reload
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
    Post.update_all('denormalized_body_length = NULL', "id = #{@poetry.id}")
    @poetry.reload
    assert !@poetry.changed?
    assert_equal nil, @poetry.denormalized_body_length
    assert @poetry.denormalized_body_length_computed_at.present?
    assert !@poetry.denormalized_value_stale_by_field?(:denormalized_body_length)
    assert !@poetry.denormalized_value_stale_by_association?(:denormalized_body_length)
    assert @poetry.denormalized_value_stale?(:denormalized_body_length)
  end
  
  def test_compute_denormalized_values
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    assert_nil(@poetry.denormalized_user_name)
    @poetry.save
    assert_equal("Ogden Nash", @poetry.denormalized_user_name)
  end
  
  def test_denormalized_attribute_triggers
    assert Post.denormalized_attribute_triggers(:denormalized_user_name).include?('user')
    assert Post.denormalized_attribute_triggers(:denormalized_user_name).include?('user_id')
    assert_equal 2, Post.denormalized_attribute_triggers(:denormalized_user_name).length
    assert Post.denormalized_attribute_triggers('denormalized_user_name').include?('user')
    assert Post.denormalized_attribute_triggers('denormalized_user_name').include?('user_id')
    assert_equal 2, Post.denormalized_attribute_triggers('denormalized_user_name').length
  end
  
  def test_triggers_default_to_all_fields
    assert_equal([], Post.denormalized_attribute_triggers(:denormalized_body_length))
    assert_equal([], Post.denormalized_attribute_triggers('denormalized_body_length'))
    assert @poetry.denormalized_value_stale?(:denormalized_body_length)
    assert @poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.save
    assert !@poetry.denormalized_value_stale?(:denormalized_body_length)
    @poetry.subject = "foo"
    assert @poetry.denormalized_value_stale?(:denormalized_body_length)
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
    @poetry.save
    assert !@poetry.denormalized_value_stale?(:denormalized_body_length)
    assert !@poetry.denormalized_value_stale?(:denormalized_user_name)
  end
  
  def test_stale_denormalized_value_with_to_many_relationship
    ogden = User.create!(:name => 'Ogden Nash')
    poetry = Post.new(:subject => 'Further Reflections on Parsley', :body => "Parsley\nIs gharsley.", :user => ogden)
    assert_equal(nil, poetry.denormalized_user_name)
    assert_equal(nil, poetry.denormalized_comments_count)
    assert poetry.denormalized_value_stale?(:denormalized_user_name)
    assert !poetry.denormalized_value_stale?(:denormalized_comments_count)
    poetry.save!
    assert_equal(ogden.name, poetry.denormalized_user_name)
    assert !poetry.denormalized_value_stale?(:denormalized_user_name)
    assert poetry.denormalized_value_stale?(:denormalized_identical_post_count)
    assert !poetry.denormalized_value_stale?(:denormalized_comments_count)
    assert poetry.is_a?(Post)
    assert poetry.respond_to?('comments')
    assert_equal [], poetry.comments
    assert poetry.comments.build(:body => 'yadda')
    assert !poetry.comments.empty?
    assert poetry.comments.first.changed?
    assert !poetry.denormalized_value_stale?(:denormalized_user_name)
    assert poetry.comments.present?
    assert poetry.comments.last.changed?
    assert poetry.denormalized_value_stale?(:denormalized_comments_count)
    poetry.save
    assert_equal(1, poetry.denormalized_comments_count)
    assert !poetry.comments.first.new_record?
    assert !poetry.denormalized_value_stale?(:denormalized_user_name)
    poetry.comments.first.body = "The dog is man's best friend."
    assert !poetry.denormalized_value_stale?(:denormalized_user_name)
    assert poetry.denormalized_value_stale?(:denormalized_comments_count)
    poetry.comments.first.save
  end
  
  def test_denormalized_value_with_always_trigger
    ogden = User.create!(:name => 'Ogden')
    poetry = Post.new(:subject => 'Dog is Man\'s best friend', :body => "He has a tail on one end", :user => ogden)
    assert poetry.denormalized_value_stale?(:denormalized_identical_post_count)
    poetry.save
    assert poetry.denormalized_value_stale?(:denormalized_identical_post_count)
  end
  
  def test_base_attribute_methods_work
    ogden = User.create!(:name => 'Ogden Nash')
    poetry = Post.new(:subject => 'Further Reflections on Parsley', :body => "Parsley\nIs gharsley.", :user => ogden)
    assert_equal nil, poetry.denormalized_user_name
    assert_equal( ogden.name, poetry.user_name )
    poetry.save!
    assert_equal ogden.name, poetry.denormalized_user_name
    assert poetry.respond_to?(:user_name)
    assert_equal ogden.name, poetry.user_name
  end
  
  def test_denormalized_value_unset?
    assert @poetry.denormalized_value_unset?(:denormalized_user_name)
    assert !@poetry.denormalized_value_unset?(:denormalized_identical_post_count)
    @poetry.save
    assert !@poetry.denormalized_value_unset?(:denormalized_user_name)
    assert !@poetry.denormalized_value_unset?(:denormalized_identical_post_count)
    @poetry.unset_denormalized_value(:denormalized_user_name)
    assert @poetry.denormalized_value_unset?(:denormalized_user_name)
    assert !@poetry.denormalized_value_unset?(:denormalized_identical_post_count)
    @poetry.save
    assert !@poetry.denormalized_value_unset?(:denormalized_user_name)
    assert !@poetry.denormalized_value_unset?(:denormalized_identical_post_count)
    @poetry.unset_denormalized_value(:denormalized_identical_post_count)
    assert !@poetry.denormalized_value_unset?(:denormalized_user_name)
    # can't detect that a value is unset if it doesn't have a corresponding timestamp
    assert !@poetry.class.corresponding_denormalization_timestamp?(:denormalized_identical_post_count)
    assert !@poetry.denormalized_value_unset?(:denormalized_identical_post_count)
  end
  
  def test_denormalized_values_unset?
    assert @poetry.denormalized_values_unset?
    @poetry.save
    @poetry.reload
    assert !@poetry.denormalized_values_unset?
  end
  
  def test_denormalized_values_unset
    assert_equal ["denormalized_user_name",
     "denormalized_comments_count",
     "denormalized_body_length"].sort, @poetry.denormalized_values_unset.sort
    @poetry.save
    @poetry.reload
    assert_equal [], @poetry.denormalized_values_unset
  end
  
  def test_with_unset_denormalized_values
    @poetry.save
    assert !Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.unset_denormalized_values_by_sql("phony_attribute_name")
    assert !Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.unset_denormalized_values_by_sql("denormalized_user_name")
    assert Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.reload
    @poetry.save
    assert !Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.unset_denormalized_values_by_sql([:foo, :denormalized_comments_count])
    assert Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.reload
    @poetry.save
    assert !Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.unset_denormalized_values_by_sql("denormalized_comments_count")
    assert Post.with_unset_denormalized_values.include?(@poetry)
    @poetry.reload
    @poetry.save
    assert !Post.with_unset_denormalized_values.include?(@poetry)
    assert_not_nil(@poetry.denormalized_identical_post_count )
    @poetry.unset_denormalized_values_by_sql(:denormalized_identical_post_count)
    @poetry.reload
    assert_nil(@poetry.denormalized_identical_post_count )
    # denormalized_identical_post_count doesn't have a corresponding timestamp,
    # so it doesn't get picked up in with_unset_denormalized_values.
    assert !Post.with_unset_denormalized_values.include?(@poetry)
  end
  
  def test_unset_all_denormalized_values
    @poetry.save
    assert !@poetry.denormalized_values_unset?
    @poetry.unset_all_denormalized_values
    assert @poetry.denormalized_values_unset?
    @poetry.save
    assert !@poetry.denormalized_values_unset?
  end

end
