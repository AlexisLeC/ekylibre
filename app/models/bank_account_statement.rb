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
# == Table: bank_account_statements
#
#  bank_account_id :integer          not null
#  company_id      :integer          not null
#  created_at      :datetime         not null
#  creator_id      :integer          
#  credit          :decimal(16, 2)   default(0.0), not null
#  debit           :decimal(16, 2)   default(0.0), not null
#  id              :integer          not null, primary key
#  intermediate    :boolean          not null
#  lock_version    :integer          default(0), not null
#  number          :string(255)      not null
#  started_on      :date             not null
#  stopped_on      :date             not null
#  updated_at      :datetime         not null
#  updater_id      :integer          
#

class BankAccountStatement < ActiveRecord::Base
  belongs_to :bank_account
  belongs_to :company

  has_many :entries, :class_name=>"Entry", :foreign_key=>:intermediate_id
  has_many :entries, :class_name=>"Entry", :foreign_key=>:statement_id

  before_destroy :statement_entry

  # A bank account statement has to contain all the planned records.
  def validate    
    errors.add_to_base lc(:error_period_statement) if self.started_on >= self.stopped_on
  end

  #
  def statement_entry
    if self.entries.size > 0
      self.entries.each do |entry|
        entry.update_attribute(:statement_id, nil)
      end
    end
  end

end
