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
# == Table: sale_order_natures
#
#  active              :boolean          default(TRUE), not null
#  comment             :text             
#  company_id          :integer          not null
#  created_at          :datetime         not null
#  creator_id          :integer          
#  downpayment         :boolean          not null
#  downpayment_minimum :decimal(16, 2)   default(0.0), not null
#  downpayment_rate    :decimal(16, 2)   default(0.0), not null
#  expiration_id       :integer          not null
#  id                  :integer          not null, primary key
#  lock_version        :integer          default(0), not null
#  name                :string(255)      not null
#  payment_delay_id    :integer          not null
#  payment_type        :string(8)        
#  updated_at          :datetime         not null
#  updater_id          :integer          
#

class SaleOrderNature < ActiveRecord::Base

  belongs_to :company
  belongs_to :payment_delay, :class_name=>Delay.to_s
  belongs_to :expiration, :class_name=>Delay.to_s
  has_many :sale_orders

  def self.payment_types
    [:card, :cash, :check,  :none, :transfer].collect{|x| [tc('payment_types.'+x.to_s), x] }
  end
  

end
