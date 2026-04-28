class AddDeliveryFieldsToPaidAdviceRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :paid_advice_requests, :delivery_body, :text
    add_column :paid_advice_requests, :delivered_at, :datetime
    add_column :paid_advice_requests, :completed_at, :datetime
  end
end
