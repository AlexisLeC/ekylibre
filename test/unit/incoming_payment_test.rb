# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2014 Brice Texier, Thibaud Merigon
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
# 
# == Table: incoming_payments
#
#  account_number        :string(255)      
#  accounted_at          :datetime         
#  amount                :decimal(16, 2)   not null
#  bank                  :string(255)      
#  check_number          :string(255)      
#  commission_account_id :integer          
#  commission_amount     :decimal(16, 2)   default(0.0), not null
#  company_id            :integer          not null
#  created_at            :datetime         not null
#  created_on            :date             
#  creator_id            :integer          
#  deposit_id            :integer          
#  id                    :integer          not null, primary key
#  journal_entry_id      :integer          
#  lock_version          :integer          default(0), not null
#  mode_id               :integer          not null
#  number                :string(255)      
#  paid_on               :date             
#  payer_id              :integer          
#  receipt               :text             
#  received              :boolean          default(TRUE), not null
#  responsible_id        :integer          
#  scheduled             :boolean          not null
#  to_bank_on            :date             default(CURRENT_DATE), not null
#  updated_at            :datetime         not null
#  updater_id            :integer          
#  used_amount           :decimal(16, 2)   not null
#


require 'test_helper'

class IncomingPaymentTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the bookkeeping of a payment" do
    payment = incoming_payments(:incoming_payments_001)
#     assert payment.company.prefer_bookkeep_automatically?
#     payment.bookkeep(:create)
#     assert_not_nil payment.journal_record
#     assert_equal payment.amount, payment.journal_record.currency_debit
#     assert_equal payment.amount, payment.journal_record.currency_credit
  end
end
