# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2016 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: fixed_asset_depreciations
#
#  accountable        :boolean          default(FALSE), not null
#  accounted_at       :datetime
#  amount             :decimal(19, 4)   not null
#  created_at         :datetime         not null
#  creator_id         :integer
#  depreciable_amount :decimal(19, 4)
#  depreciated_amount :decimal(19, 4)
#  financial_year_id  :integer
#  fixed_asset_id     :integer          not null
#  id                 :integer          not null, primary key
#  journal_entry_id   :integer
#  lock_version       :integer          default(0), not null
#  locked             :boolean          default(FALSE), not null
#  position           :integer
#  started_on         :date             not null
#  stopped_on         :date             not null
#  updated_at         :datetime         not null
#  updater_id         :integer
#
class FixedAssetDepreciation < Ekylibre::Record::Base
  acts_as_list scope: :fixed_asset
  belongs_to :fixed_asset
  belongs_to :financial_year
  belongs_to :journal_entry
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :started_on, :stopped_on, timeliness: { allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.today + 50.years }, type: :date }
  validates :accounted_at, timeliness: { allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }
  validates :stopped_on, timeliness: { allow_blank: true, on_or_after: :started_on }, if: ->(fixed_asset_depreciation) { fixed_asset_depreciation.stopped_on && fixed_asset_depreciation.started_on }
  validates :amount, :depreciable_amount, :depreciated_amount, numericality: { allow_nil: true }
  validates :accountable, :locked, inclusion: { in: [true, false] }
  validates :amount, :fixed_asset, :started_on, :stopped_on, presence: true
  # ]VALIDATORS]
  validates :financial_year, presence: true
  delegate :currency, to: :fixed_asset

  sums :fixed_asset, :depreciations, amount: :depreciated_amount

  bookkeep(on: :nothing) do |b|
    b.journal_entry do |_entry|
    end
  end

  before_validation do
    self.depreciated_amount = fixed_asset.depreciations.where('stopped_on < ?', started_on).sum(:amount) + amount
    self.depreciable_amount = fixed_asset.depreciable_amount - depreciated_amount
  end

  validate do
    # A start day must be the depreciation start or a financial year start
    if fixed_asset && financial_year
      unless started_on == fixed_asset.started_on || started_on.beginning_of_month == started_on || started_on == financial_year.started_on
        errors.add(:started_on, :invalid_date, start: fixed_asset.started_on)
      end
    end
  end

  # Returns the duration of the depreciation
  def duration
    FixedAsset.duration(started_on, stopped_on, mode: fixed_asset.depreciation_method.to_sym)
  end
end
