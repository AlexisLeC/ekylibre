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
# == Table: manure_management_plans
#
#  annotation     :text
#  campaign_id    :integer          not null
#  created_at     :datetime         not null
#  creator_id     :integer
#  id             :integer          not null, primary key
#  lock_version   :integer          default(0), not null
#  locked         :boolean          default(FALSE), not null
#  name           :string           not null
#  opened_at      :datetime         not null
#  recommender_id :integer          not null
#  updated_at     :datetime         not null
#  updater_id     :integer
#
class ManureManagementPlan < Ekylibre::Record::Base
  include Attachable
  belongs_to :campaign
  belongs_to :recommender, class_name: 'Entity'
  has_many :zones, class_name: 'ManureManagementPlanZone', dependent: :destroy, inverse_of: :plan, foreign_key: :plan_id
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :opened_at, timeliness: { allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }
  validates :locked, inclusion: { in: [true, false] }
  validates :campaign, :name, :opened_at, :recommender, presence: true
  # ]VALIDATORS]

  accepts_nested_attributes_for :zones


  protect do
    locked?
  end

  # after_save :compute
  scope :of_campaign, lambda{ |campaign|
    if campaign.is_a?(Fixnum)
      where(:campaign_id => campaign)
    else
      where(:campaign_id => campaign.id)
    end
  }

  def self.manure_georeadings
    natures = ManureManagementPlan.manure_georeading_types
    Georeading.where(kind: natures)
  end

  def compute
    zones.map(&:compute)
  end

  def zones_in_vulnerable_area
    res = []
    (ActiveRecord::Base.connection.execute("SELECT distinct MMPZ.id
                                                  FROM MANURE_MANAGEMENT_PLANS as MMP
                                                  JOIN MANURE_MANAGEMENT_PLAN_ZONES as MMPZ ON MMPZ.plan_id = MMP.id
                                                  JOIN ACTIVITY_PRODUCTIONS as AP on MMPZ.activity_production_id = AP.id
                                                  LEFT JOIN REGULATORY_ZONES as RZ on ST_Intersects(RZ.shape,AP.support_shape)
                                                  WHERE RZ.type = 'VulnerableZone'
                                                  ;")).values.map{|item| item.first}
  end

  def build_missing_zones
    active = false
    active = true if zones.empty?
    return false unless campaign
    campaign.activity_productions.includes(:support).order(:activity_id, 'products.name').each do |activity_production|
      # activity_production.active? return all activies except fallow_land
      next unless activity_production.support.is_a?(LandParcel) && activity_production.active?
      next if zones.find_by(activity_production: activity_production)
      zone = zones.build(
        activity_production: activity_production,
        administrative_area: activity_production.support.administrative_area,
        cultivation_variety: activity_production.cultivation_variety,
        soil_nature: activity_production.support.soil_nature || activity_production.support.estimated_soil_nature
      )
      zone.estimate_expected_yield
    end
  end

  def self.budgets_done(campaign)
    activities_prod = ActivityProduction.of_campaign(campaign).of_activity_families("plant_farming")

    missing_budgets = []
    activities_prod.each do |activity_production|
      missing_budgets << activity_production.budgets.of_campaign(campaign).select{|budget| budget.revenues.empty?}
    end
    missing_info = {budget: missing_budgets.reject(&:empty?),
                    cultivation_variety: activities_prod.select{ |act| act.cultivation_variety.nil?} }
    activities_prod.select{ |act| act.cultivation_variety.nil?}

    missing_info["valid"] = missing_info[:budget].empty? && missing_info[:cultivation_variety].empty?
    #check soil nature

    return missing_info
  end

  def mass_density_unit
    :quintal_per_hectare
  end

  def self.manure_georeading_types
    [:well, :water, :drinkingwater, :bathing_place, :shellfish_waters, :steep_slopes]
  end
end
