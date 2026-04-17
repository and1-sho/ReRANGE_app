class MessagesController < ApplicationController
  before_action :authenticate_user!

  def index
    @requests = if current_user.trainer?
                  Request.where(directed_to_trainer_id: current_user.id)
                else
                  current_user.requests.where.not(directed_to_trainer_id: nil)
                end
    @requests = @requests.includes(:user, video_attachment: :blob, video_thumbnail_attachment: :blob)
                           .order(created_at: :desc)
  end
end
