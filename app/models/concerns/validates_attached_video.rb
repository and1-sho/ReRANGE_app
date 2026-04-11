# Request / Advice 共通: has_one_attached :video 向け（MP4・MOV・100MB）
module ValidatesAttachedVideo
  extend ActiveSupport::Concern

  MAX_VIDEO_BYTES = 100.megabytes
  ALLOWED_VIDEO_CONTENT_TYPES = %w[video/mp4 video/quicktime].freeze

  included do
    validate :validate_mp4_mov_video_attachment, if: -> { video.attached? }
  end

  private

  def validate_mp4_mov_video_attachment
    blob = video.blob
    unless allowed_video_blob?(blob)
      errors.add(:video, "はMP4またはMOV（.mp4 / .mov）にしてください")
      return
    end
    if blob.byte_size > MAX_VIDEO_BYTES
      errors.add(:video, "は100MB以下にしてください")
    end
  end

  def allowed_video_blob?(blob)
    ct = blob.content_type
    return true if ALLOWED_VIDEO_CONTENT_TYPES.include?(ct)

    fn = blob.filename.to_s.downcase
    return true if fn.end_with?(".mp4", ".mov") && ct == "application/octet-stream"

    false
  end
end
