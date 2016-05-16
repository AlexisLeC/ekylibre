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
# == Table: plant_counting_items
#
#  created_at        :datetime         not null
#  creator_id        :integer
#  id                :integer          not null, primary key
#  lock_version      :integer          default(0), not null
#  plant_counting_id :integer          not null
#  updated_at        :datetime         not null
#  updater_id        :integer
#  value             :integer          not null
#

class PlantCountingItem < Ekylibre::Record::Base
  belongs_to :plant_counting, inverse_of: :items

  after_save :update_average_value
  after_destroy :update_average_value

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_numericality_of :value, allow_nil: true, only_integer: true
  validates_presence_of :plant_counting, :value
  # ]VALIDATORS]

  def update_average_value
    items = plant_counting.items
    average_value = items.any? ? items.average(:value) : nil
    plant_counting.update_column(:average_value, average_value)
  end

  def siblings
    plant_counting.items
  end
end
