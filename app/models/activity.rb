# coding: utf-8
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
# == Table: activities
#
#  created_at          :datetime         not null
#  creator_id          :integer
#  cultivation_variety :string
#  description         :text
#  family              :string           not null
#  id                  :integer          not null, primary key
#  lock_version        :integer          default(0), not null
#  name                :string           not null
#  nature              :string           not null
#  support_variety     :string
#  updated_at          :datetime         not null
#  updater_id          :integer
#  with_cultivation    :boolean          not null
#  with_supports       :boolean          not null
#
class Activity < Ekylibre::Record::Base
  refers_to :family, class_name: 'ActivityFamily'
  refers_to :cultivation_variety, class_name: 'Variety'
  refers_to :support_variety, class_name: 'Variety'
  enumerize :nature, in: [:main, :auxiliary, :standalone], default: :main, predicates: true
  has_many :distributions, -> { order(:main_activity_id) }, class_name: 'ActivityDistribution', dependent: :destroy, inverse_of: :activity
  has_many :productions
  has_many :supports, through: :productions
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_inclusion_of :with_cultivation, :with_supports, in: [true, false]
  validates_presence_of :family, :name, :nature
  # ]VALIDATORS]
  validates_inclusion_of :family, in: family.values, allow_nil: true
  validates_presence_of :family
  validates_presence_of :cultivation_variety, if: :with_cultivation
  validates_presence_of :support_variety, if: :with_supports
  validates_uniqueness_of :name
  validates_associated :productions

  scope :main, -> { where(nature: 'main') }
  scope :actives, -> { where(id: Production.actives.pluck(:activity_id)) }
  scope :availables, -> { order(:name) }
  # scope :main_activity, -> { where(nature: "main") }
  scope :of_campaign, lambda { |*campaigns|
    campaigns.flatten!
    if campaigns.detect { |campaign| !campaign.is_a?(Campaign) }
      fail ArgumentError, "Expected Campaign, got #{campaign.class.name}:#{campaign.inspect}"
    end
    where(id: Production.of_campaign(campaigns).pluck(:activity_id))
  }

  scope :of_families, proc { |*families|
    where(family: families.flatten.collect { |f| Nomen::ActivityFamily.all(f.to_sym) }.flatten.uniq.map(&:to_s))
  }

  accepts_nested_attributes_for :distributions, reject_if: :all_blank, allow_destroy: true

  before_validation do
    if family = Nomen::ActivityFamily[self.family]
      if with_supports.nil?
        if variety = family.support_variety
          self.with_supports = true
          self.support_variety = variety
        else
          self.with_supports = false
        end
      end
      if with_cultivation.nil?
        if variety = family.cultivation_variety
          self.with_cultivation = true
          self.cultivation_variety = variety
        else
          self.with_cultivation = false
        end
      end
    end
    true
  end

  validate do
    if family = Nomen::ActivityFamily[self.family]
      if with_supports && variety = Nomen::Variety[support_variety]
        errors.add(:support_variety, :invalid) unless variety <= family.support_variety
      end
      if with_cultivation && variety = Nomen::Variety[cultivation_variety]
        errors.add(:cultivation_variety, :invalid) unless variety <= family.cultivation_variety
      end
    end
    true
  end

  before_save do
    self.support_variety = nil unless with_supports
    self.cultivation_variety = nil unless with_cultivation
  end

  after_save do
    if auxiliary? && distributions.any?
      total = distributions.sum(:affectation_percentage)
      if total != 100
        sum = 0
        distributions.each do |distribution|
          percentage = (distribution.affectation_percentage * 100.0 / total).round(2)
          sum += percentage
          distribution.update_column(:affectation_percentage, percentage)
        end
        if sum != 100
          distribution = distributions.last
          distribution.update_column(:affectation_percentage, distribution.affectation_percentage + (100 - sum))
        end
      end
    else
      distributions.clear
    end
  end

  protect(on: :destroy) do
    productions.any?
  end

  def family_label
    Nomen::ActivityFamily.find(family).human_name
  end

  # Returns a color for each activity depending on families
  # FIXME: Only refers to activity family to prevent
  # short-way solution must be externalized in mid-way solution
  def color
    colors = { gold: '#FFD700', golden_rod: '#DAA520', yellow: '#FFFF00',
               orange: '#FF8000', red: '#FF0000', green: '#80FF00',
               spring_green: '#00FF7F', dark_green: '#006400',
               dark_turquoise: '#00FFFF', blue: '#0000FF', purple: '#BF00FF',
               gray: '#A4A4A4', dark_magenta: '#8B008B', violet: '#EE82EE',
               teal: '#008080', fuchsia: '#FF00FF', brown: '#6A2B1A' }
    activity_family = Nomen::ActivityFamily.find(family)
    return colors[:gray] unless activity_family
    if activity_family <= :vegetal_crops
      # ARBO, FRUIT = BLUE
      if activity_family <= :arboriculture
        colors[:blue]
      elsif activity_family <= :field_crops
        # level 3 - category - CEREALS = GOLD/YELLOW/ORANGE
        if activity_family <= :cereal_crops
          # level 4 - variety
          if activity_family <= :maize_crops || activity_family <= :sorghum_crops
            colors[:orange]
          elsif activity_family <= :barley_crops
            colors[:yellow]
          else
            colors[:gold]
          end
        # level 3 - category - BEETS / POTATO = VIOLET
        elsif activity_family <= :beet_crops
          colors[:violet]
        # level 3 - category - FODDER = SPRING GREEN
        elsif activity_family <= :fodder_crops ||
              activity_family <= :fallow_land
          colors[:dark_green]
        elsif activity_family <= :meadow
          colors[:dark_green]
        # level 3 - category - PROTEINS = TEAL
        elsif activity_family <= :protein_crops
          colors[:teal]
        # level 3 - category - OILSEED = GOLDEN ROD
        elsif activity_family <= :oilseed_crops
          colors[:golden_rod]
        # level 3 - category - BEETS / POTATO = VIOLET
        elsif activity_family <= :potato_crops
          colors[:violet]
        # level 3 - category - AROMATIC, TOBACCO, HEMP = TURQUOISE
        elsif activity_family <= :tobacco_crops ||
              activity_family <= :hemp_crops
          colors[:dark_turquoise]
        else
          colors[:gray]
        end
      elsif activity_family <= :aromatic_and_medicinal_plants
        colors[:dark_turquoise]
      # level 3 - category - FLOWER = FUCHSIA
      elsif activity_family <= :flower_crops
        colors[:fuchsia]
      # level 3 - category - ARBO, FRUIT = BLUE
      elsif activity_family <= :fruits_crops
        colors[:blue]
      # level 3 - category - MARKET = RED
      elsif activity_family <= :market_garden_crops
        colors[:red]
      else
        colors[:gray]
      end
    elsif activity_family <= :animal_farming
      colors[:brown]
    else
      colors[:gray]
    end
  end

  class << self
    def find_best_family(cultivation_variety, support_variety)
      rankings = Nomen::ActivityFamily.list.inject({}) do |hash, item|
        valid = true
        valid = false unless !cultivation_variety == !item.cultivation_variety
        distance = 0
        if valid && cultivation_variety
          if Nomen::Variety[cultivation_variety] <= item.cultivation_variety
            distance += Nomen::Variety[cultivation_variety].depth - Nomen::Variety[item.cultivation_variety].depth
          else
            valid = false
          end
        end
        if valid && support_variety
          if Nomen::Variety[support_variety] <= item.support_variety
            distance += Nomen::Variety[support_variety].depth - Nomen::Variety[item.support_variety].depth
          else
            valid = false
          end
        end
        hash[item.name] = distance if valid
        hash
      end.sort { |a, b| a.second <=> b.second }
      if best_choice = rankings.first
        return Nomen::ActivityFamily.find(best_choice.first)
      end
      nil
    end
  end

  def shape_area(*campaigns)
    productions.of_campaign(campaigns).map(&:shape_area).compact.sum
  end

  def net_surface_area(*campaigns)
    productions.of_campaign(campaigns).map(&:net_surface_area).compact.sum
  end

  def area(*campaigns)
    # raise "NO AREA"
    ActiveSupport::Deprecation.warn("#{self.class.name}#area is deprecated. Please use #{self.class.name}#net_surface_area instead.")
    net_surface_area(*campaigns)
  end

  def interventions_duration(*campaigns)
    productions.of_campaign(campaigns).map(&:duration).compact.sum
  end

  def is_of_family?(family)
    Nomen::ActivityFamily[self.family] <= family
  end
end
