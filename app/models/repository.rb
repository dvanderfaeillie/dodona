# == Schema Information
#
# Table name: repositories
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  remote     :string(255)
#  path       :string(255)
#  judge_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'open3'

class Repository < ApplicationRecord
  include Gitable

  CONFIG_FILE = 'config.json'.freeze
  EXERCISE_LOCATIONS = Rails.root.join('data', 'exercises').freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :remote, presence: true
  validates :path, presence: true, uniqueness: { case_sensitive: false }
  validates :judge, presence: true

  validate :repo_is_accessible, on: :create

  before_create :clone_repo

  belongs_to :judge
  has_many :exercises

  def full_path
    File.join(EXERCISE_LOCATIONS, path)
  end

  def config
    file = File.join(full_path, CONFIG_FILE)
    if File.file? file
      JSON.parse(File.read(file))
    else
      {}
    end
  end

  def commit(msg)
    _out, error, status = Open3.capture3('git', 'commit', '--author="Dodona <dodona@ugent.be>"', '-am', msg, chdir: full_path)
    _out, error, status = Open3.capture3('git push', chdir: full_path) if status.success?
    [status.success?, error]
  end
end
