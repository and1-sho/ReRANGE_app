class RenameCoachTermsToTrainer < ActiveRecord::Migration[7.1]
  def up
    begin
      remove_foreign_key :requests, column: :directed_to_coach_id
    rescue ArgumentError, ActiveRecord::StatementInvalid
      # schema と実 DB で FK の有無が一致しない環境向け
    end

    rename_column :requests, :directed_to_coach_id, :directed_to_trainer_id

    begin
      add_foreign_key :requests, :users, column: :directed_to_trainer_id
    rescue ArgumentError, ActiveRecord::StatementInvalid
    end

    rename_column :users, :coaching_started_on, :instruction_started_on
  end

  def down
    rename_column :users, :instruction_started_on, :coaching_started_on

    begin
      remove_foreign_key :requests, column: :directed_to_trainer_id
    rescue ArgumentError, ActiveRecord::StatementInvalid
    end

    rename_column :requests, :directed_to_trainer_id, :directed_to_coach_id

    begin
      add_foreign_key :requests, :users, column: :directed_to_coach_id
    rescue ArgumentError, ActiveRecord::StatementInvalid
    end
  end
end
