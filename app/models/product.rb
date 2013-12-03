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
# == Table: products
#
#  active                 :boolean          default(TRUE), not null
#  catalog_description    :text             
#  catalog_name           :string(255)      not null
#  charge_account_id      :integer          
#  code                   :string(8)        
#  code2                  :string(64)       
#  comment                :text             
#  company_id             :integer          not null
#  created_at             :datetime         not null
#  creator_id             :integer          
#  critic_quantity_min    :decimal(16, 4)   default(1.0)
#  description            :text             
#  ean13                  :string(13)       
#  id                     :integer          not null, primary key
#  lock_version           :integer          default(0), not null
#  manage_stocks          :boolean          not null
#  name                   :string(255)      not null
#  nature                 :string(8)        not null
#  number                 :integer          not null
#  price                  :decimal(16, 2)   default(0.0)
#  product_account_id     :integer          
#  quantity_max           :decimal(16, 4)   default(0.0)
#  quantity_min           :decimal(16, 4)   default(0.0)
#  reduction_submissive   :boolean          not null
#  service_coeff          :decimal(16, 4)   
#  shelf_id               :integer          not null
#  subscription_nature_id :integer          
#  subscription_period    :string(255)      
#  subscription_quantity  :integer          
#  to_produce             :boolean          not null
#  to_purchase            :boolean          not null
#  to_rent                :boolean          not null
#  to_sale                :boolean          default(TRUE), not null
#  unit_id                :integer          not null
#  unquantifiable         :boolean          not null
#  updated_at             :datetime         not null
#  updater_id             :integer          
#  weight                 :decimal(16, 3)   
#

class Product < ActiveRecord::Base

  belongs_to :charge_account, :class_name=>Account.to_s
  belongs_to :company
  belongs_to :product_account, :class_name=>Account.to_s
  belongs_to :subscription_nature
  belongs_to :shelf
  belongs_to :unit
  has_many :components, :class_name=>ProductComponent.name, :conditions=>{:active=>true}
  has_many :delivery_lines
  has_many :invoice_lines
  has_many :prices
  has_many :purchase_order_lines
  # TODO rename locations to reservoirs
  has_many :locations, :conditions=>{:reservoir=>true}
  has_many :sale_order_lines
  has_many :stock_moves
  has_many :stock_transfers
  has_many :stocks
  has_many :subscriptions
  has_many :trackings

  @@natures = [:product, :service, :subscrip, :transfer]

  attr_readonly :company_id

  validates_uniqueness_of :code, :scope=>:company_id

  validates_presence_of :subscription_period, :if=>Proc.new{|u| u.nature=="sub_date"}
  validates_presence_of :subscription_numbers, :actual_number, :if=>Proc.new{|u| u.nature=="sub_numb"}
  validates_presence_of :product_account_id, :if=>Proc.new{|p| p.to_sale}
  validates_presence_of  :charge_account_id, :if=>Proc.new{|p| p.to_purchase}

  #validates_presence_of :product_account_id
  #validates_presence_of :charge_account_id

  def before_validation
    self.code = self.name.codeize.upper if self.code.blank?
    self.code = self.code[0..7]
    if self.company_id
      if self.number.blank?
        last = self.company.products.find(:first, :order=>'number DESC')
        self.number = last.nil? ? 1 : last.number+1 
      end
      while self.company.products.find(:first, :conditions=>["code=? AND id!=?", self.code, self.id||0])
        self.code.succ!
      end
    end
    self.to_produce = true if self.has_components?
    self.catalog_name = self.name if self.catalog_name.blank?
    self.subscription_nature_id = nil if self.nature != "subscrip"
    self.service_coeff = nil if self.nature != "service"
    
  end
 
  def to
    to = []
    to << :sale if self.to_sale
    to << :purchase if self.to_purchase
    to << :rent if self.to_rent
    to << :produce if self.to_produce
    to.collect{|x| tc('to.'+x.to_s)}.to_sentence
  end

  def validate
    #errors.add_to_base(lc(:unknown_use_of_product)) unless self.to_sale or self.to_purchase or self.to_rent
  end

  def self.natures
    @@natures.collect{|x| [tc('natures.'+x.to_s), x] }
  end

  def units
    self.company.units.find(:all, :conditions=>{:base=>self.unit.base}, :order=>"coefficient, label")
  end

  def has_components?
    self.components.size > 0
  end

  def default_price(category_id)
    self.prices.find(:first, :conditions=>{:category_id=>category_id, :active=>true, :default=>true})
  end

  def label
    tc('label', :product=>self.name, :unit=>self.unit.label)
  end

  def informations
    tc('informations.'+(self.has_components? ? 'with' : 'without')+'_components', :product=>self.name, :unit=>self.unit.label, :size=>self.components.size)
  end

  def duration
    #raise Exception.new self.subscription_nature.nature.inspect+" blabla"
    if self.subscription_nature
      self.send('subscription_'+self.subscription_nature.nature)
    else
      return nil
    end
    
  end
  
  def duration=(value)
    #raise Exception.new subscription.inspect+self.subscription_nature_id.inspect
    if self.subscription_nature
      self.send('subscription_'+self.subscription_nature.nature+'=', value)
    end
  end

  def default_start
    # self.subscription_nature.nature == "period" ? Date.today.beginning_of_year : self.subscription_nature.actual_number
    self.subscription_nature.nature == "period" ? Date.today : self.subscription_nature.actual_number
  end

  def default_finish
    period = self.subscription_period || '1 year'
    # self.subscription_nature.nature == "period" ? Date.today.next_year.beginning_of_year.next_month.end_of_month : (self.subscription_nature.actual_number + ((self.subscription_quantity-1)||0))
    self.subscription_nature.nature == "period" ? Delay.compute(period+", 1 day ago", Date.today) : (self.subscription_nature.actual_number + ((self.subscription_quantity-1)||0))
  end

  def shelf_name
    self.shelf.name
  end


  # Create real stocks moves to update the real state of stocks
  def move_outgoing_stock(options={})
    add_stock_move(options.merge(:virtual=>false, :incoming=>false))
  end

  def move_incoming_stock(options={})
    add_stock_move(options.merge(:virtual=>false, :incoming=>true))
  end

  # Create virtual stock moves to reserve the products
  def reserve_outgoing_stock(options={})
    add_stock_move(options.merge(:virtual=>true, :incoming=>false))
  end

  def reserve_incoming_stock(options={})
    add_stock_move(options.merge(:virtual=>true, :incoming=>true))
  end

  # Create real stocks moves to update the real state of stocks
  def move_stock(options={})
    add_stock_move(options.merge(:virtual=>false))
  end

  # Create virtual stock moves to reserve the products
  def reserve_stock(options={})
    add_stock_move(options.merge(:virtual=>true))
  end


  # Generic method to add stock move in product's stock
  def add_stock_move(options={})
    return true unless self.manage_stocks
    incoming = options.delete(:incoming)
    attributes = options.merge(:generated=>true, :company_id=>self.company_id)
    origin = options[:origin]
    if origin.is_a? ActiveRecord::Base
      code = [:number, :code, :name, :id].detect{|x| origin.respond_to? x}
      attributes[:name] = tc('stock_move', :origin=>(origin ? ::I18n.t("activerecord.models.#{origin.class.name.underscore}") : "*"), :code=>(origin ? origin.send(code) : "*"))
      for attribute in [:quantity, :unit_id, :tracking_id, :location_id, :product_id]
        unless attributes.keys.include? attribute
          attributes[attribute] ||= origin.send(attribute) rescue nil
        end
      end
    end
    attributes[:quantity] = -attributes[:quantity] unless incoming
    attributes[:location_id] ||= self.locations.first.id
    attributes[:planned_on] ||= Date.today
    attributes[:moved_on] ||= attributes[:planned_on] unless attributes.keys.include? :moved_on
    self.stock_moves.create!(attributes)
  end

  
end
