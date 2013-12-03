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
# == Table: account_balances
#
#  account_id       :integer          not null
#  company_id       :integer          not null
#  created_at       :datetime         not null
#  creator_id       :integer          
#  financialyear_id :integer          not null
#  global_balance   :decimal(16, 2)   default(0.0), not null
#  global_count     :integer          default(0), not null
#  global_credit    :decimal(16, 2)   default(0.0), not null
#  global_debit     :decimal(16, 2)   default(0.0), not null
#  id               :integer          not null, primary key
#  local_balance    :decimal(16, 2)   default(0.0), not null
#  local_count      :integer          default(0), not null
#  local_credit     :decimal(16, 2)   default(0.0), not null
#  local_debit      :decimal(16, 2)   default(0.0), not null
#  lock_version     :integer          default(0), not null
#  updated_at       :datetime         not null
#  updater_id       :integer          
#

class AccountBalance < ActiveRecord::Base
  belongs_to :account
  belongs_to :company
  belongs_to :financialyear
  
  # validates_uniqueness_of :account, :name, :label 



   #lists the accounts used in a given period with the credit and the debit.
   def self.balance(period)
     accounts = self.find(:all, :conditions=>{:financialyear_id=>period})
     
     unless accounts.empty?
       results = Hash.new
       
       accounts.each do |account|
         
         results[account.id] = Hash.new
         detail_account = Account.find(account.id)
         
         results[account.id][:number] = detail_account.number
         results[account.id][:name] = detail_account.name
         results[account.id][:debit] = account.local_debit
         results[account.id][:credit] = account.local_credit
         results[account.id][:total_debit] = account.global_debit
         results[account.id][:global_credit] = account.global_credit
       end
       results
     end
     
   end

   def self.sum(accounts, period)
   end

   
end
