class CreateAdvices < ActiveRecord::Migration[7.1]
  def change
    create_table :advices do |t|
      t.text :body
      t.references :request, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
