# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Mérigon
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
# == Table: delays
#
#  active       :boolean          default(TRUE), not null
#  comment      :text             
#  company_id   :integer          not null
#  created_at   :datetime         not null
#  creator_id   :integer          
#  expression   :string(255)      not null
#  id           :integer          not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string(255)      not null
#  updated_at   :datetime         not null
#  updater_id   :integer          
#

class Delay < ActiveRecord::Base
 
  belongs_to :company
  has_many :entities
  has_many :invoices
  has_many :sale_orders
  has_many :sale_order_natures

  attr_readonly :company_id

  DELAY_SEPARATOR = ', '

  def before_validation
    self.expression = self.expression.squeeze(" ").lower
    self.expression.split(/\s*\,\s*/).collect{|x| x.strip}.join(DELAY_SEPARATOR)
  end

  def validate
    errors.add(:expression, I18n.t('activerecord.errors.messages.invalid')) if self.compute(Date.today).nil?
  end

  def compute(started_on=Date.today)
    Delay.compute(self.expression, started_on)
  end


  def self.compute(delay_expression, started_on=Date.today)
    return nil if started_on.nil?
    steps = delay_expression.to_s.split(/\s*\,\s*/)||[]
    stopped_on = started_on
    steps.each do |step|
      if step.match(/^(eom|end of month|fdm|fin de mois)$/)
        stopped_on = stopped_on.end_of_month
      elsif step.match /^\d+\ (an|année|annee|year|mois|month|week|semaine|jour|day|heure|hour)s?(\ (avant|ago))?$/
        words = step.split " "
        sign = words[2].nil? ? 1 : -1                  ## "ago" in step ?
        case words[1].gsub(/s$/,'')
        when "jour", "day"
          stopped_on += sign*words[0].to_i             ## date = date + x days (x>0 if not "ago" in step , else x<0)
        when "semaine", "week"
          stopped_on += sign*words[0].to_i*7           ## date = date + x weeks (x>0 if not "ago" in step , else x<0)
        when "moi", "month"
          if sign > 0
            stopped_on = stopped_on >> words[0].to_i   ## date = date - x months
          else 
            stopped_on = stopped_on << words[0].to_i   ## date = date + x months
          end
        when "an", "annee", "année", "year"
          if sign > 0
            stopped_on = stopped_on >> words[0].to_i*12   ## date = date - x years
          else
            stopped_on = stopped_on << words[0].to_i*12   ## date = date + x years
          end
        end 
      else
        return nil
      end
    end
    #raise Exception.new stopped_on.inspect
    stopped_on
  end


end
