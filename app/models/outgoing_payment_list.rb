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
# == Table: outgoing_payment_lists
#
#  created_at   :datetime
#  creator_id   :integer
#  id           :integer          not null, primary key
#  lock_version :integer          default(0), not null
#  number       :string
#  updated_at   :datetime
#  updater_id   :integer
#
class OutgoingPaymentList < Ekylibre::Record::Base
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :number, length: { maximum: 500 }, allow_blank: true
  # ]VALIDATORS]
  has_many :payments, class_name: 'OutgoingPayment', foreign_key: :list_id, inverse_of: :list, dependent: :destroy

  delegate :name, to: :mode, prefix: true
  delegate :sepa?, to: :mode
  delegate :count, to: :payments, prefix: true

  acts_as_numbered

  protect(on: :destroy) do
    JournalEntryItem.where(entry_id: payments.select(:entry_id)).where('LENGTH(TRIM(bank_statement_letter)) > 0').any?
  end

  def mode
    payments.first.mode unless payments.first.nil?
  end

  def currency
    mode.cash.currency
  end

  def to_sepa
    sct = SEPA::CreditTransfer.new(
      name: mode.cash.bank_account_holder_name.truncate(70, omission: ''),
      bic: mode.cash.bank_identifier_code || 'NOTPROVIDED',
      iban: mode.cash.iban
    )

    sct.message_identification =
      "EKY-#{number}-#{Time.zone.now.strftime('%y%m%d-%H%M')}"

    payments.each do |payment|
      credit_transfer_params = {
        name: payment.payee.bank_account_holder_name.truncate(70, omission: ''),
        iban: payment.payee.iban,
        amount: format('%.2f', payment.amount.round(2)),
        reference: payment.number,
        remittance_information: payment.affair.purchases.first.number,
        requested_date: Time.zone.now.to_date,
        batch_booking: false
      }

      credit_transfer_params[:bic] = if payment.payee.bank_identifier_code.present?
                                       payment.payee.bank_identifier_code
                                     else
                                       'NOTPROVIDED'
                                     end

      sct.add_transaction(credit_transfer_params)
    end

    sct.to_xml('pain.001.001.03')
  end

  def payments_sum
    payments.sum(:amount)
  end

  def self.build_from_purchases(purchases, mode, responsible)
    outgoing_payments = purchases.map do |purchase|
      OutgoingPayment.new(
        affair: purchase.affair,
        amount: purchase.amount,
        cash: mode.cash,
        currency: purchase.currency,
        delivered: true,
        mode: mode,
        paid_at: Time.zone.today,
        payee: purchase.payee,
        responsible: responsible,
        to_bank_at: Time.zone.today
      )
    end

    new(payments: outgoing_payments)
  end
end
