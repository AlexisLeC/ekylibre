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
# == Table: loans
#
#  accounted_at         :datetime
#  amount               :decimal(19, 4)   not null
#  cash_id              :integer          not null
#  created_at           :datetime         not null
#  creator_id           :integer
#  currency             :string           not null
#  id                   :integer          not null, primary key
#  insurance_percentage :decimal(19, 4)   not null
#  interest_percentage  :decimal(19, 4)   not null
#  journal_entry_id     :integer
#  lender_id            :integer          not null
#  lock_version         :integer          default(0), not null
#  name                 :string           not null
#  repayment_duration   :integer          not null
#  repayment_method     :string           not null
#  repayment_period     :string           not null
#  shift_duration       :integer          default(0), not null
#  shift_method         :string
#  started_on           :date             not null
#  updated_at           :datetime         not null
#  updater_id           :integer
#
class Loan < Ekylibre::Record::Base
  include Attachable
  enumerize :repayment_method, in: [:constant_rate, :constant_amount], default: :constant_amount
  enumerize :shift_method, in: [:immediate_payment, :anatocism], default: :immediate_payment
  enumerize :repayment_period, in: [:month, :year], default: :month, predicates: { prefix: true }
  refers_to :currency
  belongs_to :cash
  belongs_to :journal_entry
  belongs_to :lender, class_name: 'Entity'
  has_many :repayments, -> { order(:position) }, class_name: 'LoanRepayment', dependent: :destroy, counter_cache: false
  has_one :journal, through: :cash
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_date :started_on, allow_blank: true, on_or_after: Date.civil(1, 1, 1)
  validates_datetime :accounted_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_numericality_of :repayment_duration, :shift_duration, allow_nil: true, only_integer: true
  validates_numericality_of :amount, :insurance_percentage, :interest_percentage, allow_nil: true
  validates_presence_of :amount, :cash, :currency, :insurance_percentage, :interest_percentage, :lender, :name, :repayment_duration, :repayment_method, :repayment_period, :shift_duration, :started_on
  # ]VALIDATORS]

  before_validation do
    self.currency ||= cash.currency if cash
    self.shift_duration ||= 0
  end

  validate do
    if self.currency && cash
      errors.add(:currency, :invalid) unless self.currency == cash.currency
    end
  end

  after_save do
    generate_repayments
  end

  bookkeep do |b|
    b.journal_entry(journal, printed_on: started_on, if: started_on <= Time.zone.today) do |entry|
      label = tc(:bookkeep, resource: self.class.model_name.human, name: name)
      entry.add_debit(label, cash.account_id, amount)
      entry.add_credit(label, Account.find_or_import_from_nomenclature(:loans).id, amount)
    end
  end

  def generate_repayments
    period = repayment_period_month? ? 12 : 1
    ids = []
    Calculus::Loan.new(amount, repayment_duration, interests: { interest_amount: interest_percentage / 100.0 }, insurances: { insurance_amount: insurance_percentage / 100.0 }, period: period, shift: self.shift_duration, shift_method: shift_method.to_sym, started_on: started_on).compute_repayments(repayment_method).each do |repayment|
      if r = repayments.find_by(position: repayment[:position])
        r.update_attributes!(repayment)
      else
        r = repayments.create!(repayment)
      end
      ids << r.id
    end
    repayments.destroy(repayments.where.not(id: ids))
    reload
  end
end
