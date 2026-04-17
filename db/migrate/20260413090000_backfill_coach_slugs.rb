class BackfillCoachSlugs < ActiveRecord::Migration[7.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    # 既存トレーナーの slug が nil の場合、プロフィールURL用に採番する
    MigrationUser.where(role: 1, slug: nil).find_each do |trainer|
      base = trainer.name.to_s.parameterize.presence || "trainer"
      candidate = base
      sequence = 1

      while MigrationUser.exists?(slug: candidate)
        sequence += 1
        candidate = "#{base}-#{sequence}"
      end

      trainer.update_columns(slug: candidate)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "既存データの slug 補完は安全に元に戻せません"
  end
end
