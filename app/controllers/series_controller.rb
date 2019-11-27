class SeriesController < ApplicationController
  before_action :set_series, except: %i[index new create indianio_download]

  before_action :check_token, only: %i[show overview]

  has_scope :at_least_one_started, type: :boolean, only: :scoresheet do |controller, scope|
    scope.at_least_one_started_in_series(Series.find(controller.params[:id]))
  end
  has_scope :by_course_labels, as: 'course_labels', type: :array, only: :scoresheet do |controller, scope, value|
    scope.by_course_labels(value, Series.find(controller.params[:id]).course_id)
  end
  has_scope :by_filter, as: 'filter', only: :scoresheet

  content_security_policy only: %i[overview] do |policy|
    policy.frame_src -> { sandbox_url }
  end

  # GET /series
  # GET /series.json
  def index
    authorize Series
    @course = Course.find(params[:course_id])
    @series = policy_scope(@course.series)
    @title = I18n.t('series.index.title')
  end

  # GET /series/1
  # GET /series/1.json
  def show
    @course = @series.course
    @title = @series.name
    @crumbs = [[@course.name, course_path(@course)], [@series.name, '#']]
    @user = User.find(params[:user_id]) if params[:user_id] && current_user&.course_admin?(@course)
  end

  def overview
    @title = "#{@series.course.name} #{@series.name}"
    @course = @series.course
    @crumbs = [[@course.name, course_path(@course)], [@series.name, course_path(@series.course, anchor: @series.anchor)], [I18n.t('crumbs.overview'), '#']]
    @user = User.find(params[:user_id]) if params[:user_id] && current_user&.course_admin?(@course)
  end

  # GET /series/new
  def new
    course = Maybe(params[:course_id])
             .map { |cid| Course.find_by id: cid }
             .or_nil
    authorize course, :add_series?
    @series = Series.new(course: course)
    @title = I18n.t('series.new.title')
    @crumbs = [[course.name, course_path(course)], [I18n.t('series.new.title'), '#']]
  end

  # GET /series/1/edit
  def edit
    @title = @series.name
    @crumbs = [[@series.course.name, course_path(@series.course)], [@series.name, course_path(@series.course, anchor: @series.anchor)], [I18n.t('crumbs.edit'), '#']]
    @labels = policy_scope(Label.all)
    @programming_languages = policy_scope(ProgrammingLanguage.all)
    @repositories = policy_scope(Repository.all)
  end

  # POST /series
  # POST /series.json
  def create
    @series = Series.new(permitted_attributes(Series))
    authorize @series.course, :add_series?
    respond_to do |format|
      if @series.save
        format.html { redirect_to edit_series_path(@series), notice: I18n.t('controllers.created', model: Series.model_name.human) }
        format.json { render :show, status: :created, location: @series }
      else
        format.html { render :new }
        format.json { render json: @series.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /series/1
  # PATCH/PUT /series/1.json
  def update
    respond_to do |format|
      if @series.update(permitted_attributes(@series))
        format.html { redirect_to course_path(@series.course, series: @series, anchor: @series.anchor), notice: I18n.t('controllers.updated', model: Series.model_name.human) }
        format.json { render :show, status: :ok, location: @series }
      else
        format.html { render :edit }
        format.json { render json: @series.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /series/1
  # DELETE /series/1.json
  def destroy
    @series.destroy
    respond_to do |format|
      format.html { redirect_to request.referer || course_path(@series.course), notice: I18n.t('controllers.destroyed', model: Series.model_name.human) }
      format.json { head :no_content }
    end
  end

  def reset_token
    type = params[:type].to_sym
    @series.generate_token(type)
    @series.save
    value =
      case type
      when :indianio_token
        @series.indianio_token
      when :access_token
        series_url(@series, token: @series.access_token)
      end
    render partial: 'application/token_field', locals: {
      container_name: :access_token_field,
      name: type,
      value: value,
      reset_url: reset_token_series_path(@series, type: type)
    }
  end

  def indianio_download
    token = params[:token]
    email = params[:email]
    @series = Series.find_by(indianio_token: token)
    if token.blank? || @series.nil?
      render json: { errors: ['Wrong token'] }, status: :unauthorized
    elsif email.blank?
      render json: { errors: ['No email given'] }, status: :unprocessable_entity
    else
      user = User.find_by(email: email)
      if user
        options = { deadline: true, only_last_submission: true, with_info: true, all_students: true, indianio: true }
        send_zip Export.new(item: @series, list: @series.exercises, users: [user], options: options).bundle
      else
        render json: { errors: ['Unknown email'] }, status: :not_found
      end
    end
  end

  def add_exercise
    @exercise = Exercise.find(params[:exercise_id])
    unless @exercise.usable_by? @series.course
      if current_user.repository_admin? @exercise.repository
        @series.course.usable_repositories << @exercise.repository
      else
        render status: :forbidden
        return
      end
    end
    SeriesMembership.create(series: @series, exercise: @exercise)
  end

  def remove_exercise
    @exercise = Exercise.find(params[:exercise_id])
    @series.exercises.destroy(@exercise)
  end

  def reorder_exercises
    order = JSON.parse(params[:order])
    @series.series_memberships.each do |membership|
      rank = order.find_index(membership.exercise_id) || 0
      membership.update(order: rank)
    end
  end

  def scoresheet
    @course = @series.course
    @title = @series.name
    @course_labels = CourseLabel.where(course: @course)

    scores = @series.scoresheet
    @users = apply_scopes(scores[:users])
    @exercises = scores[:exercises]
    @submissions = scores[:submissions]

    @crumbs = [[@course.name, course_path(@course)], [@series.name, course_path(@series.course, anchor: @series.anchor)], [I18n.t('crumbs.overview'), '#']]

    respond_to do |format|
      format.html
      format.js
      format.csv do
        sheet = CSV.generate do |csv|
          csv << [I18n.t('series.scoresheet.explanation')]
          csv << [User.human_attribute_name('first_name'), User.human_attribute_name('last_name'), User.human_attribute_name('username'), User.human_attribute_name('email'), @series.name].concat(@exercises.map(&:name))
          csv << ['Maximum', '', '', '', @exercises.count].concat(@exercises.map { 1 })
          @users.each do |u|
            row = [u.first_name, u.last_name, u.username, u.email]
            succeeded_exercises = @exercises.map { |e| @submissions[[u.id, e.id]]&.accepted ? 1 : 0 }
            row << succeeded_exercises.sum
            row.concat(succeeded_exercises)
            csv << row
          end
        end
        filename = "scoresheet-#{@series.name.parameterize}.csv"
        send_data(sheet, type: 'text/csv', filename: filename, disposition: 'attachment', x_sendfile: true)
      end
    end
  end

  def mass_rejudge
    @submissions = Submission.in_series(@series)
    Submission.rejudge(@submissions)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_series
    @series = Series.find(params[:id])
    authorize @series
  end

  def check_token
    raise Pundit::NotAuthorizedError if @series.hidden? &&
                                        !current_user&.course_admin?(@series.course) &&
                                        @series.access_token != params[:token]
  end
end
