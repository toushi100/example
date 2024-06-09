class V1::Supervisors::SessionsController < V1::Supervisors::ApplicationController
  before_action :set_viewed_sessions, only: [:index]

  def index
    sessions = current_supervisor.sessions
    sessions = sessions.arrange(params[:order_by]) if params[:order_by].present?
    sessions, pagination_meta = sessions.paginate(**page_params)
    render json: { results: V1::SessionSerializer.render_as_hash(sessions, view: :with_student_or_candidate, viewed_sessions: @viewed_sessions), meta: pagination_meta }
  end

  def set_as_seen
    sessions = params[:viewed_sessions_ids]
    session_is_viewed = SessionIsViewedSerivce.new(sessions, current_supervisor)
    if session_is_viewed.perform
      head :ok
    else
      render json: { message: "viewed_session_ids cannot be empty" }, status: :unprocessable_entity
    end
  end

  private

  def set_viewed_sessions
    user_key = "session_seen_by_#{current_supervisor.class.name}_#{current_supervisor.id}"
    @viewed_sessions = $redis.smembers(user_key)
  end
end

class SessionIsViewedSerivce < ApplicationService
  attr_accessor :sessions, :user, :user_type

  def initialize(sessions, user)
    self.sessions = sessions
    self.user = user
    self.user_type = user.class.name
  end

  def perform
    return false if sessions.blank?
    user_key = "session_seen_by_#{user_type}_#{user.id}"
    $redis.sadd(user_key, sessions)
    super
  end
end

class V1::SessionSerializer < V1::ApplicationSerializer
  fields :date, :start_time, :end_time

  field :viewed do |session, options|
    if options[:viewed_sessions].present?
      options[:viewed_sessions].include?(session.id.to_s)
    else
      false
    end
  end
end

