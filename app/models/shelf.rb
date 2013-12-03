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
# == Table: shelves
#
#  catalog_description :text             
#  catalog_name        :string(255)      not null
#  comment             :text             
#  company_id          :integer          not null
#  created_at          :datetime         not null
#  creator_id          :integer          
#  id                  :integer          not null, primary key
#  lock_version        :integer          default(0), not null
#  name                :string(255)      not null
#  parent_id           :integer          
#  updated_at          :datetime         not null
#  updater_id          :integer          
#

class Shelf < ActiveRecord::Base
  belongs_to :company
  has_many :products
  has_many :shelves

  acts_as_tree

  def before_validation
    self.catalog_name = self.name if self.catalog_name.blank?
  end

  def to_s
    self.name
  end

  def depth
    if self.parent.nil?
      0
    else
      self.parent.depth+1
    end
  end

end
