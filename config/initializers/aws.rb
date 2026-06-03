# ============================================================
# AWS SDK の設定
#
# Cloudflare R2 は Amazon S3 と互換性があるが、
# 新しい aws-sdk-s3 (1.172.0 以降) はファイル送信時に
# 複数のチェックサム（整合性確認コード）を自動で付けるようになった。
# しかし R2 は1種類しか受け付けないため InvalidRequest エラーになる。
#
# `when_required` に設定することで、必要な時だけチェックサムを付けるようにして回避する。
# ============================================================

Aws.config.update({
  request_checksum_calculation: "when_required",
  response_checksum_validation: "when_required"
})
