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
# == Table: events
#
#  company_id     :integer          not null
#  created_at     :datetime         not null
#  creator_id     :integer          
#  duration       :integer          
#  entity_id      :integer          not null
#  id             :integer          not null, primary key
#  location       :string(255)      
#  lock_version   :integer          default(0), not null
#  nature_id      :integer          not null
#  reason         :text             
#  responsible_id :integer          not null
#  started_at     :datetime         not null
#  started_sec    :integer          not null
#  updated_at     :datetime         not null
#  updater_id     :integer          
#


