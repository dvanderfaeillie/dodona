class Export < ApplicationRecord
  include ExportHelper

  AUTOMATICALLY_DELETE_AFTER = 30.days

  belongs_to :user
  has_one_attached :archive
  enum status: { started: 0, finished: 1, failed: 2 }

  default_scope { order(id: :desc) }

  def start(item, list, users, params)
    bundle = Zipper.new(
      item: item,
      users: users,
      list: list,
      options: params
    ).bundle

    archive.attach(
      io: StringIO.new(bundle[:data]),
      filename: bundle[:filename],
      content_type: 'application/zip',
      identify: false
    )

    delay(queue: 'cleaning', run_at: AUTOMATICALLY_DELETE_AFTER.from_now).destroy
    update(status: :finished)
  end
end
