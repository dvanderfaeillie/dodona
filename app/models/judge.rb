# == Schema Information
#
# Table name: judges
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  image      :string(255)
#  path       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  renderer   :string(255)      not null
#  runner     :string(255)      not null
#

class Judge < ApplicationRecord
  CONFIG_FILE = 'config.json'.freeze
  JUDGE_LOCATIONS = Rails.root.join('data', 'judges')

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :image, presence: true
  validates :path, presence: true, uniqueness: { case_sensitive: false }
  validate :renderer_is_renderer
  validate :runner_is_runner

  has_many :repositories
  has_many :exercises

  def full_path
    File.join(JUDGE_LOCATIONS, path)
  end

  def config
    JSON.parse(File.read(File.join(full_path, CONFIG_FILE)))
  end

  def renderer
    klass = read_attribute(:renderer)
    ActiveSupport::Inflector.constantize klass if klass
  end

  def renderer=(klass)
    write_attribute :renderer, klass.to_s
  end

  def renderer_is_renderer
    begin
      unless renderer <= FeedbackTableRenderer
        errors.add(:renderer, "should be a subclass of FeedbackTableRenderer")
        return false
      end
    rescue
      errors.add(:renderer, "should be a class in scope")
      return false
    end
    true
  end

  def runner
    klass = read_attribute(:runner)
    ActiveSupport::Inflector.constantize klass if klass
  end

  def runner=(klass)
    write_attribute :runner, klass.to_s
  end

  def runner_is_runner
    begin
      unless runner <= SubmissionRunner
        errors.add(:runner, "should be a subclass of SubmissionRunner")
        return false
      end
    rescue
      errors.add(:runner, "should be a class in scope")
      return false
    end
    true
  end

end
