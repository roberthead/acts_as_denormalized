ActiveRecord::Schema.define(:version => 0) do
  drop_table(:posts) rescue nil
  drop_table(:comments) rescue nil
  drop_table(:users) rescue nil
  create_table :posts do |t|
    t.string :subject
    t.text :body
    t.belongs_to :user
    t.string :denormalized_user_name
    t.datetime :denormalized_user_name_computed_at
    t.integer :denormalized_comments_count
    t.datetime :denormalized_comments_count_computed_at
    t.integer :denormalized_body_length
    t.datetime :denormalized_body_length_computed_at
    t.integer :denormalized_identical_post_count
    t.timestamps
  end
  create_table :users do |t|
    t.string :name
    t.timestamps
  end
  create_table :comments do |t|
    t.integer :post_id
    t.string :body
    t.timestamps
  end
end
