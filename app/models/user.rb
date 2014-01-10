# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2010 Brice Texier, Thibaud Mérigon
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
# == Table: users
#
#  admin             :boolean          default(TRUE), not null
#  arrived_on        :date             
#  comment           :text             
#  commercial        :boolean          
#  company_id        :integer          not null
#  created_at        :datetime         not null
#  creator_id        :integer          
#  credits           :boolean          default(TRUE), not null
#  deleted_at        :datetime         
#  departed_on       :date             
#  department_id     :integer          
#  email             :string(255)      
#  employed          :boolean          not null
#  employment        :string(255)      
#  establishment_id  :integer          
#  first_name        :string(255)      not null
#  free_price        :boolean          default(TRUE), not null
#  hashed_password   :string(64)       
#  id                :integer          not null, primary key
#  language_id       :integer          not null
#  last_name         :string(255)      not null
#  lock_version      :integer          default(0), not null
#  locked            :boolean          not null
#  name              :string(32)       not null
#  office            :string(255)      
#  profession_id     :integer          
#  reduction_percent :decimal(, )      default(5.0), not null
#  rights            :text             
#  role_id           :integer          not null
#  salt              :string(64)       
#  updated_at        :datetime         not null
#  updater_id        :integer          
#

require "digest/sha2"

class User < ActiveRecord::Base
  belongs_to :company
  belongs_to :department
  belongs_to :establishment
  belongs_to :language
  belongs_to :profession
  belongs_to :role
  has_many :clients, :class_name=>Entity.to_s, :foreign_key=>:responsible_id
  has_many :events
  has_many :parameters
  has_many :sale_orders, :foreign_key=>:responsible_id
  has_many :operations, :foreign_key=>:responsible_id
  has_many :transports, :foreign_key=>:responsible_id
  


  validates_presence_of :password, :password_confirmation, :if=>Proc.new{|u| u.new_record?}
  validates_confirmation_of :password
  validates_inclusion_of :reduction_percent, :in=>0..100
  validates_uniqueness_of :name # , :scope=>:company_id

  # cattr_accessor :current_user
  attr_accessor :password_confirmation, :old_password
  attr_protected :hashed_password, :salt, :locked, :deleted_at, :rights
  attr_readonly :company_id

  # Needed to stamp all records
  model_stamper

  class << self
    def rights_file; "#{RAILS_ROOT}/config/rights.txt"; end
    def minimum_right; :__minimum__; end
    def rights; @@rights; end
    def rights_list; @@rights_list; end
    def useful_rights; @@useful_rights; end
  end
  
  def before_validation
    self.name = self.name.to_s.strip.downcase.gsub(/[^a-z0-9\.\_]/,'')
    if self.company
      self.language = self.company.parameter('general.language').value if self.language.nil?
    end
    self.language = Language.find(:first, :order=>:name) if self.language.nil?
    self.admin = true if self.rights.nil?
    self.rights_array=self.rights_array # Clean the rights
  end

  def label
    self.first_name+' '+self.last_name
  end

  def parameter(name, value=nil, nature=:string)
    p = self.parameters.find(:first, :order=>:id, :conditions=>{:name=>name})
    p = self.parameters.create!(:name=>name, :company_id=>self.company_id, :nature=>nature.to_s, :value=>value) if p.nil?
    return p
  end


  def rights_array
    self.rights.to_s.split(" ").collect{|x| x.to_sym}
  end

  def rights_array=(array)
    narray = array.select{|x| User.rights_list.include? x.to_sym}.collect{|x| x.to_sym}
    self.rights = narray.join(" ")
    return narray
  end

  def diff_more(right_markup = 'div', separator='')
    (self.rights_array-self.role.rights_array).collect{|x| "<#{right_markup}>"+::I18n.t("rights.#{x}")+"</#{right_markup}>"}.join(separator)
  end


  def diff_less(right_markup = 'div', separator='')
    (self.role.rights_array-self.rights_array).collect{|x| "<#{right_markup}>"+::I18n.t("rights.#{x}")+"</#{right_markup}>"}.join(separator)
  end

  def password
    @password
  end
  
  def password=(passwd)
    @password = passwd
    unless self.password.blank?
      self.salt = User.generate_password(64)
      self.hashed_password = User.encrypted_password(self.password, self.salt)
    end
  end

  def self.authenticate(name, password, company=nil)
    user = nil
    if company.nil?
      users = self.find_all_by_name(name.downcase)
      user = users[0] if users.size == 1
    else
      user = self.find_by_name_and_company_id(name.downcase, company.id)
    end
    if user
      user = nil if user.locked or user.deleted_at or !user.authenticated?(password)
    end
    user
  end

  def authorization(rights_list, controller_name, action_name)
    message = nil
    if User.rights[controller_name.to_sym].nil?
      message = tc(:no_right_defined_for_this_part_of_the_application, :controller=>controller_name, :action=>action_name)
    elsif (right = User.rights[controller_name.to_sym][action_name.to_sym]).nil?
      message = tc(:no_right_defined_for_this_part_of_the_application, :controller=>controller_name, :action=>action_name)
    elsif not right == User.minimum_right and not rights_list.include?(right) and not self.admin
      message = tc(:no_right_defined_for_this_part_of_the_application_and_this_user)
    end
    return message
  end
  
  def after_destroy
    if User.count.zero?
      raise "Impossible to destroy the last user"
    end
  end

  def authenticated?(password)
    self.hashed_password == User.encrypted_password(password, self.salt)
  end

  # Used for generic password creation
  def self.give_password(length=8, mode=:complex)
    User.generate_password(length, mode)
  end

  private

  def self.encrypted_password(password, salt)
    string_to_hash = "<"+password.to_s+":"+salt.to_s+"/>"
    Digest::SHA256.hexdigest(string_to_hash)
  end

  def self.generate_password(password_length=8, mode=:complex)
    return '' if password_length.blank? or password_length<1
    case mode
      when :dummy  : letters = %w(a b c d e f g h j k m n o p q r s t u w x y 3 4 6 7 8 9)
      when :simple : letters = %w(a b c d e f g h j k m n o p q r s t u w x y A B C D E F G H J K M N P Q R T U W Y X 3 4 6 7 8 9)
      when :normal : letters = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W Y X Z 0 1 2 3 4 5 6 7 8 9)
      else           letters = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W Y X Z 0 1 2 3 4 5 6 7 8 9 _ = + - * | [ ] { } . : ; ! ? , § µ % / & < >)
    end
    letters_length = letters.length
    password = ''
    password_length.times{password+=letters[(letters_length*rand).to_i]}
    password
  end


  def self.initialize_rights
    @@rights = {}
    @@rights_list = []
    @@useful_rights = {}
    file = File.open(User.rights_file, "rb") 
    file.each_line do |line|
      line = line.strip.split(/[\:\t\,\;\s]+/)
      unless line[0].match(/\#/) or line[2].to_s.match(/^\w+$/).nil?
        @@rights[line[0].to_sym] ||= {}
        @@rights[line[0].to_sym][line[1].to_sym] = line[2].to_sym 
        @@rights_list << line[2].to_sym 
      end
    end
    @@rights_list.uniq!
    for controller, actions in @@rights
      unless [:authentication, :help].include? controller
        @@useful_rights[controller] = actions.values.uniq.delete_if{|x| x == User.minimum_right }
      end
    end
  end
   
  
  User.initialize_rights
end


# class Emmployee < ActiveRecord::Base
#   belongs_to :company
#   belongs_to :department
#   belongs_to :establishment
#   belongs_to :profession
#   belongs_to :user
#   has_many :clients, :class_name=>Entity.to_s
#   has_many :events
#   has_many :sale_orders, :foreign_key=>:responsible_id
#   has_many :operations
#   has_many :transports

#   attr_readonly :company_id

#   def before_validation
#     self.last_name ||= self.user.last_name  
#     self.first_name ||= self.user.first_name  
#   end

#   def full_name
#     (self.last_name.to_s+" "+self.first_name.to_s).strip
#   end

#   def label
#     (self.first_name.to_s+" "+self.last_name.to_s).strip
#   end  

# end
