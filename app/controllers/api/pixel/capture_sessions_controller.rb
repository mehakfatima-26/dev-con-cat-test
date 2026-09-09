module Api
  module Pixel
    class CaptureSessionsController < BaseController
      before_action :find_and_authorize_pixel!

      def create
        existing = CaptureSession.find_by(session_id: params[:session_id])
        return handle_existing(existing) if existing

        CaptureSession.create!(
          pixel: pixel, account: pixel.account, session_id: params[:session_id],
          page_url: params[:page_url], referrer: params[:referrer],
          visit_ip: request.remote_ip, user_agent: request.user_agent,
          started_at: params[:started_at] || Time.current
        )

        head :accepted
      end

      private

      def handle_existing(existing)
        return render_forbidden("session_id already used by a different pixel") unless existing.pixel_id == pixel.id

        head :accepted
      end
    end
  end
end
