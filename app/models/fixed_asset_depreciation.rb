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
  validates_date :started_on, :stopped_on, allow_blank: true, on_or_after: Date.civil(1, 1, 1)
  validates_datetime :accounted_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_numericality_of :amount, :depreciable_amount, :depreciated_amount, allow_nil: true
  validates_inclusion_of :accountable, :locked, in: [true, false]
  validates_presence_of :amount, :fixed_asset, :started_on, :stopped_on
  # ]VALIDATORS]
  validates_presence_of :financial_year
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
