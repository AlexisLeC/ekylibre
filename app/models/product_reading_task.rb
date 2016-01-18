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
# == Table: product_reading_tasks
#
#  absolute_measure_value_unit  :string
#  absolute_measure_value_value :decimal(19, 4)
#  boolean_value                :boolean          default(FALSE), not null
#  choice_value                 :string
#  created_at                   :datetime         not null
#  creator_id                   :integer
#  decimal_value                :decimal(19, 4)
#  geometry_value               :geometry({:srid=>4326, :type=>"geometry"})
#  id                           :integer          not null, primary key
#  indicator_datatype           :string           not null
#  indicator_name               :string           not null
#  integer_value                :integer
#  lock_version                 :integer          default(0), not null
#  measure_value_unit           :string
#  measure_value_value          :decimal(19, 4)
#  operation_id                 :integer
#  originator_id                :integer
#  originator_type              :string
#  point_value                  :geometry({:srid=>4326, :type=>"point"})
#  product_id                   :integer          not null
#  reporter_id                  :integer
#  started_at                   :datetime         not null
#  stopped_at                   :datetime
#  string_value                 :text
#  tool_id                      :integer
#  updated_at                   :datetime         not null
#  updater_id                   :integer
#
class ProductReadingTask < Ekylibre::Record::Base
  include Taskable, TimeLineable, ReadingStorable
  belongs_to :product
  belongs_to :reporter, class_name: 'Worker'
  belongs_to :tool, class_name: 'Product'
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :started_at, :stopped_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_numericality_of :integer_value, allow_nil: true, only_integer: true
  validates_numericality_of :absolute_measure_value_value, :decimal_value, :measure_value_value, allow_nil: true
  validates_inclusion_of :boolean_value, in: [true, false]
  validates_presence_of :indicator_datatype, :indicator_name, :product, :started_at
  # ]VALIDATORS]

  validate do
    if product && indicator
      unless product.indicators.include?(indicator)
        puts product.inspect.red + indicator.inspect + product.indicators.inspect.green
        errors.add(:indicator_name, :invalid)
      end
    end
  end

  after_create do
    product.read!(indicator, value, at: started_at)
    # reading = self.product_readings.build(product: self.product, indicator: self.indicator, read_at: self.stopped_at)
    # reading.value = self.value
    # reading.save!
  end

  def siblings
    product.reading_tasks
  end
end
