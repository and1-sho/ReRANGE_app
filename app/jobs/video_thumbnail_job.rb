require "open3"

# Request / Advice 共通: has_one_attached :video / :video_thumbnail
class VideoThumbnailJob < ApplicationJob
  queue_as :default

  def perform(record_class_name, record_id)
    klass = record_class_name.safe_constantize
    return unless klass

    record = klass.find_by(id: record_id)
    return unless record&.video&.attached?

    ffmpeg = ffmpeg_executable
    unless ffmpeg
      Rails.logger.warn("VideoThumbnailJob: ffmpeg が見つかりません record=#{record_class_name} id=#{record_id}")
      return
    end

    record.video.blob.open(tmpdir: Rails.root.join("tmp")) do |file|
      video_path = file.path

      Dir.mktmpdir("video_thumb") do |dir|
        out_path = File.join(dir, "thumb.jpg")
        err = capture_thumbnail_with_ffmpeg(ffmpeg, video_path, out_path)
        if err
          Rails.logger.warn("VideoThumbnailJob: ffmpeg 失敗 record=#{record_class_name} id=#{record_id} #{err}")
          return
        end

        record.reload
        return unless record.video.attached?

        File.open(out_path, "rb") do |thumb_io|
          record.video_thumbnail.attach(
            io: thumb_io,
            filename: "thumbnail.jpg",
            content_type: "image/jpeg"
          )
        end
        Rails.logger.info("VideoThumbnailJob: サムネ作成 OK record=#{record_class_name} id=#{record_id}")
      end
    end
  end

  private

  def capture_thumbnail_with_ffmpeg(ffmpeg, video_path, out_path)
    seek_seconds = seek_times_for_thumbnail(video_path)
    last_err = nil

    seek_seconds.each do |ss|
      File.delete(out_path) if File.exist?(out_path)
      cmd = build_ffmpeg_thumb_cmd(ffmpeg, video_path, out_path, ss)
      _out, err, status = Open3.capture3(*cmd)
      last_err = err
      next unless status.success? && File.exist?(out_path) && File.size(out_path).positive?

      return nil
    end

    last_err.presence || "ffmpeg が有効なサムネ画像を出力しませんでした"
  end

  def seek_times_for_thumbnail(video_path)
    times = []
    dur = video_duration_seconds(video_path)
    if dur && dur > 1
      t25 = [[dur * 0.25, dur - 0.2].min, 0.1].max
      t10 = [[dur * 0.1, dur - 0.2].min, 0.1].max
      times << t25
      times << t10 if (t10 - t25).abs >= 0.05
    end
    times.concat([3, 2, 1, 0.5, 0])
    times.uniq
  end

  def video_duration_seconds(video_path)
    ffprobe = ffprobe_executable
    return nil unless ffprobe

    out, _err, status = Open3.capture3(
      ffprobe, "-v", "error", "-show_entries", "format=duration",
      "-of", "default=nw=1:nk=1", video_path
    )
    return nil unless status.success?

    Float(out, exception: false)
  end

  def build_ffmpeg_thumb_cmd(ffmpeg, video_path, out_path, ss)
    [ffmpeg, "-y", "-loglevel", "error", "-i", video_path, "-ss", ss.to_s, "-frames:v", "1",
     "-vf", "scale=320:-2", "-q:v", "5", out_path]
  end

  def ffprobe_executable
    return @ffprobe_exe if defined?(@ffprobe_exe)

    @ffprobe_exe = ENV["FFPROBE_PATH"].presence || `command -v ffprobe 2>/dev/null`.strip.presence
  end

  def ffmpeg_executable
    return @ffmpeg_exe if defined?(@ffmpeg_exe)

    @ffmpeg_exe = ENV["FFMPEG_PATH"].presence || `command -v ffmpeg 2>/dev/null`.strip.presence
  end
end
