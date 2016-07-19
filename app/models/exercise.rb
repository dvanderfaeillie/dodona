# == Schema Information
#
# Table name: exercises
#
#  id                 :integer          not null, primary key
#  name_nl            :string(255)
#  name_en            :string(255)
#  visibility         :integer          default("open")
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  path               :string(255)
#  description_format :string(255)
#  repository_id      :integer
#  judge_id           :integer
#

require 'action_view'
include ActionView::Helpers::DateHelper

class Exercise < ApplicationRecord
  CONFIG_FILE = 'config.json'.freeze
  DESCRIPTION_DIR = 'descriptions'.freeze

  # old
  MEDIA_DIR = 'media'.freeze
  PUBLIC_DIR = Rails.root.join('public', 'exercises').freeze

  enum visibility: [:open, :hidden, :closed]

  belongs_to :repository
  belongs_to :judge
  has_many :submissions

  validates :path, presence: true, uniqueness: { scope: :repository_id, case_sensitive: false }
  validates :repository_id, presence: true
  validates :judge_id, presence: true

  def full_path
    File.join(repository.full_path, path)
  end

  def name
    send('name_' + I18n.locale.to_s) || name_nl || name_en
  end

  def description_localized(lang = I18n.locale.to_s)
    file = File.join(full_path, DESCRIPTION_DIR, "description.#{lang}.#{description_format}")
    File.read(file) if FileTest.exists?(file)
  end

  def description_nl
    description_localized('nl')
  end

  def description_en
    description_localized('en')
  end

  def description
    desc = description_localized || description_nl || description_en
    if description_format == 'md'
      markdown(desc)
    else
      desc.html_safe
    end
  end

  def update_data(config, j_id)
    self.name_nl = config['names']['nl']
    self.name_en = config['names']['en']
    self.judge_id = j_id if j_id
    self.description_format = determine_format
    save
    # do something with the media dir
  end

  def determine_format
    if ['description.nl.html', 'description.en.html'].any? { |f| FileTest.exists?(File.join(full_path, DESCRIPTION_DIR, f)) }
      return 'html'
    else
      return 'md'
    end
  end

  # old
  def copy_media
    media_src = File.join(full_path, MEDIA_DIR)
    media_dst = File.join PUBLIC_DIR, name
    if FileTest.exists? media_src
      Dir.mkdir media_dst unless FileTest.exists? media_dst
      FileUtils.cp_r media_src, media_dst
    end
  end

  def users_correct
    submissions.where(status: :correct).distinct.count(:user_id)
  end

  def users_tried
    submissions.all.distinct.count(:user_id)
  end

  def last_correct_submission(user)
    submissions.of_user(user).where(status: :correct).limit(1).first
  end

  def last_submission(user)
    submissions.of_user(user).limit(1).first
  end

  def status_for(user)
    return :correct if submissions.of_user(user).where(status: :correct).count > 0
    return :wrong if submissions.of_user(user).where(status: :wrong).count > 0
    :unknown
  end

  def number_of_submissions_for(user)
    submissions.of_user(user).count
  end

  def solving_speed_for(user)
    subs = submissions.of_user(user)
    return '' if subs.count < 2
    distance_of_time_in_words(subs.first.created_at, subs.last.created_at)
  end

  # old
  def self.refresh(changed)
    msg = `cd #{DATA_DIR} && git pull 2>&1`
    status = $CHILD_STATUS.exitstatus
    Exercise.process_directories(changed)
    [status, msg]
  end

  def self.process_repository(repository)
    Exercise.process_directory(repository, '/')
  end

  def self.process_directories(repository, directories)
    directories.each { |dir| Exercise.process_directory(repository, dir) }
  end

  def self.process_directory(repository, directory)
    path = File.join(repository.full_path, directory)
    config_file = File.join(path, CONFIG_FILE)
    if File.file? config_file
      config = JSON.parse(File.read(config_file))
      Exercise.process_exercise(repository, directory, config)
    else
      Dir.entries(path)
         .select { |entry| File.directory?(File.join(path, entry)) && !entry.start_with?('.') }
         .each { |entry| Exercise.process_directory(repository, File.join(directory, entry)) }
    end
  end

  def self.process_exercise(repository, directory, config)
    ex = Exercise.where(path: directory, repository_id: repository.id).first
    j = Judge.find_by_name(config['judge'])
    j_id = j.nil? ? repository.judge_id : j.id

    if ex.nil?
      ex = Exercise.create(path: directory, repository_id: repository.id, judge_id: j_id)
    end

    ex.update_data(config, j_id)
  end

  def self.exercise_directory?(path)
    config_file = File.join(path, CONFIG_FILE)
    File.file? config_file
  end
end
