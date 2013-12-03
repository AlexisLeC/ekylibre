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
# == Table: transfers
#
#  accounted_at :datetime         
#  amount       :decimal(16, 2)   default(0.0), not null
#  comment      :string(255)      
#  company_id   :integer          not null
#  created_at   :datetime         not null
#  created_on   :date             
#  creator_id   :integer          
#  id           :integer          not null, primary key
#  label        :string(255)      
#  lock_version :integer          default(0), not null
#  parts_amount :decimal(16, 2)   default(0.0), not null
#  started_on   :date             
#  stopped_on   :date             
#  supplier_id  :integer          
#  updated_at   :datetime         not null
#  updater_id   :integer          
#

class Transfer < ActiveRecord::Base
  belongs_to :company
  belongs_to :supplier, :class_name=>Entity.to_s
  attr_readonly :company_id, :comment
  has_many :payment_parts, :as=>:expense

  validates_presence_of :created_on

  def before_validation
    self.created_on ||= Date.today
    self.parts_amount = self.payment_parts.sum(:amount)||0
  end

  def unpaid_amount(options=nil)
    self.amount - self.parts_amount
  end

  #this method saves the transfer in the accountancy module.
  def to_accountancy
    journal_purchase = self.company.journals.find(:first, :conditions => ['nature = ?', 'purchase'],:order=>:id)
    financialyear = self.company.financialyears.find(:first, :conditions => ["(? BETWEEN started_on and stopped_on) AND closed=?", '%'+Date.today.to_s+'%', false])
    unless financialyear.nil? or journal_purchase.nil?
      record = self.company.journal_records.create!(:resource_id=>self.id, :resource_type=>self.class.name, :created_on=>Date.today, :printed_on => self.started_on, :journal_id=>journal_purchase.id, :financialyear_id => financialyear.id)
      supplier_account = self.supplier.account(:supplier)
      record.add_debit(self.supplier.full_name, supplier_account.id, self.amount, :draft=>true)
      record.add_credit(tc(:payable_bills), "Compte effets à payer", self.amount, :draft=>true)
      self.update_attribute(:accounted_at, Time.now)
    end
  end


end
