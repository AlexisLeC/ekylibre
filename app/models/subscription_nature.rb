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
# == Table: subscription_natures
#
#  actual_number         :integer
#  created_at            :datetime         not null
#  creator_id            :integer
#  description           :text
#  entity_link_direction :string
#  entity_link_nature    :string
#  id                    :integer          not null, primary key
#  lock_version          :integer          default(0), not null
#  name                  :string           not null
#  nature                :string           not null
#  reduction_percentage  :decimal(19, 4)
#  updated_at            :datetime         not null
#  updater_id            :integer
#

class SubscriptionNature < Ekylibre::Record::Base
  attr_readonly :nature
  enumerize :nature, in: [:period, :quantity], default: :period, predicates: true
  refers_to :entity_link_nature, class_name: 'EntityLinkNature'
  enumerize :entity_link_direction, in: [:direct, :indirect, :all], default: :all, predicates: { prefix: true }
  has_many :product_nature_categories
  has_many :subscriptions, foreign_key: :nature_id

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_numericality_of :actual_number, allow_nil: true, only_integer: true
  validates_numericality_of :reduction_percentage, allow_nil: true
  validates_presence_of :name, :nature
  # ]VALIDATORS]
  validates_length_of :entity_link_direction, allow_nil: true, maximum: 30
  validates_length_of :entity_link_nature, allow_nil: true, maximum: 120
  validates_numericality_of :reduction_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100

  # default_scope -> { order(:name) }

  before_validation do
    self.reduction_percentage ||= 0
  end

  protect(on: :destroy) do
    subscriptions.any? || product_nature_categories.any?
  end

  def now
    (period? ? Time.zone.today : actual_number)
  end

  def fields
    if period?
      return :started_at, :stopped_at
    else
      return :first_number, :last_number
    end
  end

  def start
    fields.first
  end

  def finish
    fields.second
  end
end
