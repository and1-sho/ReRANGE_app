# FightHub 開発用の初期データ（シード）
# 実行: bin/rails db:seed
#
# まずは「development のときだけ動かす」ことと、共通パスワードを決めます。

return unless Rails.env.development?

SEED_PASSWORD = "password123"

# メールで探し、いなければ作る（2回目以降の db:seed でも安全）
# メンバーを追加
User.find_or_create_by!(email: "member1@example.test") do |user|
  user.name = "テストメンバー1"
  user.role = :member
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

User.find_or_create_by!(email: "member2@example.test") do |user|
  user.name = "テストメンバー2"
  user.role = :member
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

User.find_or_create_by!(email: "member3@example.test") do |user|
  user.name = "テストメンバー3"
  user.role = :member
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

# トレーナーを追加
User.find_or_create_by!(email: "trainer1@example.test") do |user|
  user.name = "テストトレーナー1"
  user.role = :trainer
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

User.find_or_create_by!(email: "trainer2@example.test") do |user|
  user.name = "テストトレーナー2"
  user.role = :trainer
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

User.find_or_create_by!(email: "trainer3@example.test") do |user|
  user.name = "テストトレーナー3"
  user.role = :trainer
  user.password = SEED_PASSWORD
  user.password_confirmation = SEED_PASSWORD
end

# リクエスト（request）5件
member1 = User.find_by!(email: "member1@example.test")
member2 = User.find_by!(email: "member2@example.test")
member3 = User.find_by!(email: "member3@example.test")

Request.find_or_create_by!(user: member1, title: "左ジャブの間合い") do |request|
  request.body = "左ジャブだけで距離を作る練習方法を知りたいです。"
end

Request.find_or_create_by!(user: member1, title: "フットワーク") do |request|
  request.body = "前後の動きが遅いので、練習メニューを教えてください。"
end

Request.find_or_create_by!(user: member2, title: "サウスポー対策") do |request|
  request.body = "右構えの相手とやるときの基本を知りたいです。"
end

Request.find_or_create_by!(user: member2, title: "ミット後の疲労") do |request|
  request.body = "3ラウンド目でバテるので改善ポイントを知りたいです。"
end

Request.find_or_create_by!(user: member3, title: "スパーリング前の準備") do |request|
  request.body = "初スパー前に意識することを教えてください。"
end

# アドバイス（advice）3件
trainer1 = User.find_by!(email: "trainer1@example.test")
trainer2 = User.find_by!(email: "trainer2@example.test")
trainer3 = User.find_by!(email: "trainer3@example.test")

request1 = Request.find_by!(user: member1, title: "左ジャブの間合い")
request2 = Request.find_by!(user: member1, title: "フットワーク")
request3 = Request.find_by!(user: member2, title: "サウスポー対策")

Advice.find_or_create_by!(request: request1) do |advice|
  advice.user = trainer1
  advice.body = "相手の前足との距離を一定に保つ意識で、ジャブを返す回数を増やしましょう。"
end

Advice.find_or_create_by!(request: request2) do |advice|
  advice.user = trainer2
  advice.body = "前後移動は小さく速く。まずは1分間、リズムを崩さず動く練習がおすすめです。"
end

Advice.find_or_create_by!(request: request3) do |advice|
  advice.user = trainer3
  advice.body = "サウスポー相手は外側を取ることを優先し、右ストレートを軸に組み立てましょう。"
end
