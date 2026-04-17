class AddDirectedToCoachToRequests < ActiveRecord::Migration[7.1]
  def change
    add_reference :requests, :directed_to_coach, null: true, foreign_key: { to_table: :users }
  end
end
