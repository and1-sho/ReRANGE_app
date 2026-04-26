class ChangeAdvicesUniqueIndexToRequestAndUser < ActiveRecord::Migration[7.1]
  def change
    remove_index :advices, :request_id if index_exists?(:advices, :request_id, unique: true)
    add_index :advices, [:request_id, :user_id], unique: true
  end
end
