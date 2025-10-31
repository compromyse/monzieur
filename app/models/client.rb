class Client < ApplicationRecord
  has_many :visits
  has_many :household_members

  accepts_nested_attributes_for :household_members, allow_destroy: true, reject_if: :all_blank

  def last_visit
    v = visits.last
    return '-' if v.nil?

    v.created_at.to_date.to_fs(:long) or '-'
  end

  def visit_history
    vs = visits
          .order(created_at: :desc)
          .pluck(:created_at)

    Hash[
      vs.group_by(&:year).map{|y, items|
        [y, items.group_by { |d| d.strftime('%B') } ]
      }
    ]
  end

  def name
    [first_name, last_name].join(' ')
  end
end
