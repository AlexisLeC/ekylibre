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
# == Table: event_natures
#
#  active       :boolean          default(TRUE), not null
#  company_id   :integer          not null
#  created_at   :datetime         not null
#  creator_id   :integer          
#  duration     :integer          
#  id           :integer          not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string(255)      not null
#  updated_at   :datetime         not null
#  updater_id   :integer          
#  usage        :string(16)       
#

class EventNature < ActiveRecord::Base
  
  belongs_to :company
  has_many :events

  attr_readonly :company_id, :name
 
  def self.usages
    [:manual, :sale_order, :purchase_order, :invoice].collect{|x| [tc('usages.'+x.to_s), x] }
  end
  
  def text_usage
    self.usage.blank? ? "" :   tc('usages.'+self.usage.to_s)
  end

end
