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
# == Table: product_ownerships
#
#  created_at      :datetime         not null
#  creator_id      :integer
#  id              :integer          not null, primary key
#  intervention_id :integer
#  lock_version    :integer          default(0), not null
#  nature          :string           not null
#  originator_id   :integer
#  originator_type :string
#  owner_id        :integer
#  product_id      :integer          not null
#  started_at      :datetime
#  stopped_at      :datetime
#  updated_at      :datetime         not null
#  updater_id      :integer
#
class ProductOwnership < Ekylibre::Record::Base
  include Taskable, TimeLineable
  belongs_to :owner, class_name: 'Entity'
  belongs_to :product
  enumerize :nature, in: [:unknown, :own, :other], default: :unknown, predicates: true
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :started_at, :stopped_at, timeliness: { allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }
  validates :stopped_at, timeliness: { allow_blank: true, on_or_after: :started_at }, if: ->(product_ownership) { product_ownership.stopped_at && product_ownership.started_at }
  validates :nature, :product, presence: true
  # ]VALIDATORS]
  validates :owner, presence: { if: :other? }

  before_validation do
    self.nature ||= (owner.blank? ? :unknown : (owner == Entity.of_company) ? :own : :other)
  end

  private

  def siblings
    product.ownerships
  end
end
