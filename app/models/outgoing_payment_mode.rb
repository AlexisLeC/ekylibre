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
# == Table: outgoing_payment_modes
#
#  active          :boolean          default(FALSE), not null
#  cash_id         :integer
#  created_at      :datetime         not null
#  creator_id      :integer
#  id              :integer          not null, primary key
#  lock_version    :integer          default(0), not null
#  name            :string           not null
#  position        :integer
#  updated_at      :datetime         not null
#  updater_id      :integer
#  with_accounting :boolean          default(FALSE), not null
#

class OutgoingPaymentMode < Ekylibre::Record::Base
  acts_as_list
  belongs_to :cash
  has_many :payments, class_name: 'OutgoingPayment', foreign_key: :mode_id, inverse_of: :mode
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_inclusion_of :active, :with_accounting, in: [true, false]
  validates_presence_of :name
  # ]VALIDATORS]
  validates_length_of :name, allow_nil: true, maximum: 50
  validates_presence_of :cash

  delegate :currency, to: :cash

  protect(on: :destroy) do
    payments.any?
  end

  def self.load_defaults
    %w(cash check transfer).each do |nature|
      cash_nature = (nature == 'cash') ? :cash_box : :bank_account
      cash = Cash.find_by(nature: cash_nature)
      next unless cash
      create!(
        name: OutgoingPaymentMode.tc("default.#{nature}.name"),
        with_accounting: true,
        cash: cash
      )
    end
  end
end
