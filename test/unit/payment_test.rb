# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Mérigon
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
# == Table: payments
#
#  account_id     :integer          
#  account_number :string(255)      
#  accounted_at   :datetime         
#  amount         :decimal(16, 2)   not null
#  bank           :string(255)      
#  check_number   :string(255)      
#  company_id     :integer          not null
#  created_at     :datetime         not null
#  created_on     :date             
#  creator_id     :integer          
#  embanker_id    :integer          
#  embankment_id  :integer          
#  entity_id      :integer          
#  id             :integer          not null, primary key
#  lock_version   :integer          default(0), not null
#  mode_id        :integer          not null
#  number         :string(255)      
#  paid_on        :date             
#  parts_amount   :decimal(16, 2)   
#  received       :boolean          default(TRUE), not null
#  scheduled      :boolean          not null
#  to_bank_on     :date             default(CURRENT_DATE), not null
#  updated_at     :datetime         not null
#  updater_id     :integer          
#

require 'test_helper'

class PaymentTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end
