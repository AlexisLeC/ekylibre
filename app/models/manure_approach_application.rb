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
# == Table: manure_management_plan_zone_approaches
#
#  approach_id                      :integer
#  id                               :integer          not null, primary key
#  manure_management_plan_nature_id :integer
#  manure_management_plan_zone_id   :integer
#  parameters                       :jsonb
#  results                          :jsonb
#

class ManureApproachApplication < Ekylibre::Record::Base
  belongs_to :manure_management_plan_zone
  belongs_to :approach
  belongs_to :manure_management_plan_nature
  has_one :manure_management_plan, through: :manure_management_plan_nature
  def self.most_relevant_approach(shape,supply_nature)
    #Return the most relevant model for a given location

    # Here we use multiple queries because we can't use comparison on aggregations efficiently.
    # We extract some results because otherwise we would have to compute it multiple times.
    # For exemple by finding the approach id associated with the largest intersection between an approach shape and the shape(param)

    # Return the area (numeric value) for the largest intersection of an approach and the shape
=begin
    shape = manure_management_plan_zone.shape
    supply_nature = manure_management_plan_nature.supply_nature
=end
    max = ActiveRecord::Base.connection.execute("(SELECT MAX(ST_AREA(ST_Intersection(Ap.shape,#{Charta.new_geometry(shape).geom}))) FROM Approaches Ap)").values.first.first

    # Returns the approaches that intersect the most (with larger area) with the shape
    intersecting_with_largest_area = ActiveRecord::Base.connection.execute("
                                          SELECT approach.id, ST_area(approach.shape)
                                          FROM Approaches approach
                                          where approach.id in (SELECT area_tab.id
                                                                FROM (SELECT App.id, ST_AREA(ST_Intersection(App.shape,#{Charta.new_geometry(shape).geom})) AS int_area
                                                                      FROM approaches App
                                                                      WHERE supply_nature = '#{supply_nature}') area_tab
                                                                WHERE #{max} = cast(int_area AS numeric))").values

    # Find the smallest intersecting area
    # because we would have to compute all area multiple time if using aggregation to find the smallest area, and then the corresponding id,
    # I choosed to use ruby

    min_couple = intersecting_with_largest_area.first
    intersecting_with_largest_area.each do |couple|
      if couple[1] < min_couple[1]
        min_couple = couple
      end
    end
    return min_couple[0]
  end

end
