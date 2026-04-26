class AddEditedToRequestsAndAdvices < ActiveRecord::Migration[7.1]
  def change
    add_column :requests, :edited, :boolean, null: false, default: false
    add_column :advices, :edited, :boolean, null: false, default: false
  end
end
