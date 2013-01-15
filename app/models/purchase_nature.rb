# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Merigon
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
# == Table: purchase_natures
#
#  active          :boolean          not null
#  comment         :text             
#  company_id      :integer          not null
#  created_at      :datetime         not null
#  creator_id      :integer          
#  currency        :string(3)        
#  id              :integer          not null, primary key
#  journal_id      :integer          
#  lock_version    :integer          default(0), not null
#  name            :string(255)      
#  updated_at      :datetime         not null
#  updater_id      :integer          
#  with_accounting :boolean          not null
#
class PurchaseNature < CompanyRecord
  belongs_to :journal
  has_many :purchases
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :currency, :allow_nil => true, :maximum => 3
  validates_length_of :name, :allow_nil => true, :maximum => 255
  validates_inclusion_of :active, :with_accounting, :in => [true, false]
  validates_presence_of :company
  #]VALIDATORS]
  validates_presence_of :journal, :if=>Proc.new{|pn| pn.with_accounting?}
  validates_presence_of :currency
  validates_uniqueness_of :name, :scope=>:company_id

  validate do
    self.journal = nil unless self.with_accounting?
    if self.journal
      errors.add(:journal, :currency_does_not_match) if self.currency != self.journal.currency
    end
  end
end
