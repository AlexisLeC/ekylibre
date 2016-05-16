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
# == Table: entities
#
#  active                    :boolean          default(TRUE), not null
#  activity_code             :string
#  authorized_payments_count :integer
#  born_at                   :datetime
#  client                    :boolean          default(FALSE), not null
#  client_account_id         :integer
#  country                   :string
#  created_at                :datetime         not null
#  creator_id                :integer
#  currency                  :string           not null
#  custom_fields             :jsonb
#  dead_at                   :datetime
#  deliveries_conditions     :string
#  description               :text
#  first_met_at              :datetime
#  first_name                :string
#  full_name                 :string           not null
#  id                        :integer          not null, primary key
#  language                  :string           not null
#  last_name                 :string           not null
#  lock_version              :integer          default(0), not null
#  locked                    :boolean          default(FALSE), not null
#  meeting_origin            :string
#  nature                    :string           not null
#  number                    :string
#  of_company                :boolean          default(FALSE), not null
#  picture_content_type      :string
#  picture_file_name         :string
#  picture_file_size         :integer
#  picture_updated_at        :datetime
#  proposer_id               :integer
#  prospect                  :boolean          default(FALSE), not null
#  reminder_submissive       :boolean          default(FALSE), not null
#  responsible_id            :integer
#  siret_number              :string
#  supplier                  :boolean          default(FALSE), not null
#  supplier_account_id       :integer
#  title                     :string
#  transporter               :boolean          default(FALSE), not null
#  updated_at                :datetime         not null
#  updater_id                :integer
#  vat_number                :string
#  vat_subjected             :boolean          default(TRUE), not null
#

require 'digest/sha2'

class Entity < Ekylibre::Record::Base
  include Versionable, Commentable, Attachable
  include Customizable
  attr_accessor :password_confirmation, :old_password
  # belongs_to :attorney_account, class_name: "Account"
  belongs_to :client_account, class_name: 'Account'
  refers_to :currency
  refers_to :language
  refers_to :country
  enumerize :nature, in: [:organization, :contact], default: :organization, predicates: true
  versionize exclude: [:full_name]
  # belongs_to :payment_mode, class_name: "IncomingPaymentMode"
  belongs_to :proposer, class_name: 'Entity'
  belongs_to :responsible, class_name: 'User'
  belongs_to :supplier_account, class_name: 'Account'
  has_many :clients, class_name: 'Entity', foreign_key: :responsible_id, dependent: :nullify
  has_many :all_addresses, class_name: 'EntityAddress', inverse_of: :entity, dependent: :destroy
  has_many :addresses, -> { actives }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :mails,     -> { actives.mails    }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :emails,    -> { actives.emails   }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :phones,    -> { actives.phones   }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :mobiles,   -> { actives.mobiles  }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :faxes,     -> { actives.faxes    }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :websites,  -> { actives.websites }, class_name: 'EntityAddress', inverse_of: :entity
  has_many :auto_updateable_addresses, -> { actives.where(mail_auto_update: true) }, class_name: 'EntityAddress'
  has_many :direct_links, class_name: 'EntityLink', foreign_key: :entity_id
  has_many :events, through: :participations
  has_many :gaps, dependent: :restrict_with_error
  has_many :issues, as: :target, dependent: :destroy
  has_many :godchildren, class_name: 'Entity', foreign_key: 'proposer_id'
  has_many :incoming_payments, foreign_key: :payer_id, inverse_of: :payer
  has_many :indirect_links, class_name: 'EntityLink', foreign_key: :linked_id
  has_many :outgoing_payments, foreign_key: :payee_id
  has_many :ownerships, class_name: 'ProductOwnership', foreign_key: :owner_id
  has_many :participations, class_name: 'EventParticipation', foreign_key: :participant_id
  has_many :purchase_invoices, -> { where(state: 'invoice').order(created_at: :desc) }, class_name: 'Purchase', foreign_key: :supplier_id
  has_many :purchases, foreign_key: :supplier_id
  has_many :purchase_items, through: :purchases, source: :items
  has_many :parcels, foreign_key: :transporter_id
  has_many :sales_invoices, -> { where(state: 'invoice').order(created_at: :desc) }, class_name: 'Sale', foreign_key: :client_id
  has_many :sales, -> { order(created_at: :desc) }, foreign_key: :client_id
  has_many :sale_opportunities, -> { order(created_at: :desc) }, foreign_key: :third_id
  has_many :managed_sales, -> { order(created_at: :desc) }, foreign_key: :responsible_id, class_name: 'Sale'
  has_many :sale_items, through: :sales, source: :items
  has_many :subscriptions, foreign_key: :subscriber_id
  has_many :tasks
  has_many :trackings, foreign_key: :producer_id
  has_many :transports, foreign_key: :transporter_id
  has_many :transporter_sales, -> { order(created_at: :desc) }, foreign_key: :transporter_id, class_name: 'Sale'
  has_many :usable_incoming_payments, -> { where('used_amount < amount') }, class_name: 'IncomingPayment', foreign_key: :payer_id
  has_many :waiting_deliveries, -> { where(state: 'ready_to_send') }, class_name: 'Parcel', foreign_key: :transporter_id

  has_one :default_mail_address, -> { where(by_default: true, canal: 'mail') }, class_name: 'EntityAddress'
  has_one :cash, class_name: 'Cash', foreign_key: :owner_id
  has_one :worker, foreign_key: :person_id
  has_picture

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :born_at, :dead_at, :first_met_at, :picture_updated_at, allow_blank: true, on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years }
  validates_numericality_of :picture_file_size, allow_nil: true, only_integer: true
  validates_inclusion_of :active, :client, :locked, :of_company, :prospect, :reminder_submissive, :supplier, :transporter, :vat_subjected, in: [true, false]
  validates_presence_of :currency, :full_name, :language, :last_name, :nature
  # ]VALIDATORS]
  validates_length_of :country, allow_nil: true, maximum: 2
  validates_length_of :language, allow_nil: true, maximum: 3
  validates_length_of :siret_number, allow_nil: true, maximum: 14
  validates_length_of :vat_number, allow_nil: true, maximum: 20
  validates_length_of :activity_code, allow_nil: true, maximum: 30
  validates_length_of :deliveries_conditions, :number, allow_nil: true, maximum: 60
  validates_attachment_content_type :picture, content_type: /image/

  alias_attribute :name, :full_name

  scope :necessary_transporters, -> { where("transporter OR id IN (SELECT transporter_id FROM #{Parcel.table_name} WHERE state != 'sent' OR delivery_id IS NULL)").order(:last_name, :first_name) }
  scope :suppliers,    -> { where(supplier: true) }
  scope :transporters, -> { where(transporter: true) }
  scope :clients,      -> { where(client: true) }
  scope :related_to, lambda { |entity|
    where("id IN (SELECT linked_id FROM #{EntityLink.table_name} WHERE entity_id = ?) OR id IN (SELECT entity_id FROM #{EntityLink.table_name} WHERE linked_id = ?)", entity.id, entity.id)
  }
  scope :users, -> { where(id: User.select(:person_id)) }
  scope :responsibles,  -> { contacts }
  scope :contacts,      -> { where(nature: 'contact') }
  scope :organizations, -> { where(nature: 'organization') }

  acts_as_numbered :number
  accepts_nested_attributes_for :mails,    reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :emails,   reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :phones,   reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :mobiles,  reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :faxes,    reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :websites, reject_if: :all_blank, allow_destroy: true

  selects_among_all :of_company

  before_validation do
    self.first_name = first_name.to_s.strip
    self.first_name = nil if organization?
    self.last_name  = last_name.to_s.strip
    # FIXME: I18nize full name computation
    self.full_name = (title.to_s + ' ' + first_name.to_s + ' ' + last_name.to_s).strip
    # unless self.nature.nil?
    # self.full_name = (self.nature.title.to_s + ' ' + self.full_name).strip unless self.nature.in_name? # or self.nature.abbreviation == "-")
    # end
    full_name.strip!
    # self.name = self.name.to_s.strip.downcase.gsub(/[^a-z0-9\.\_]/,'')
    self.language = Preference[:language] if language.blank?
    self.currency = Preference[:currency] if currency.blank?
    self.country  = Preference[:country]  if country.blank?
  end

  validate do
    unless siret_number.blank?
      errors.add(:siret_number, :invalid) unless Luhn.valid?(siret_number.strip)
    end
    # if self.nature
    #   if self.nature.in_name and not self.last_name.match(/( |^)#{self.nature.title}( |$)/i)
    #     errors.add(:last_name, :missing_title, :title => self.nature.title)
    #   end
    # end
  end

  after_save do
    auto_updateable_addresses.find_each do |a|
      a.mail_line_1 = full_name
      a.save
    end
  end

  protect(on: :destroy) do
    of_company? || sales_invoices.any? || participations.any? || sales.any? || parcels.any?
  end

  class << self
    # Auto-cast entity to best matching class with type column
    def new_with_cast(*attributes, &block)
      if (h = attributes.first).is_a?(Hash) && !h.nil? &&
         (type = h[:type] || h['type']) && !type.empty? &&
         (klass = type.constantize) != self
        raise "Can not cast #{name} to #{klass.name}" unless klass <= self
        return klass.new(*attributes, &block)
      end
      new_without_cast(*attributes, &block)
    end
    alias_method_chain :new, :cast

    def exportable_columns
      content_columns.delete_if do |c|
        [:active, :lock_version, :deliveries_conditions].include?(c.name.to_sym)
      end
    end

    # Returns a default company entity.
    # TODO: Externalizes these informations to prevent export/overwriting errors
    def of_company
      company = find_by(of_company: true)
      unless company
        user = User.order(:id).first
        company = Entity.create!(
          nature: :organization,
          last_name: user ? user.last_name : 'COMPANY',
          of_company: true
        )
      end
      company
    end
  end

  # Returns an entity scope for.all other entities
  def others
    self.class.where('id != ?', (id || 0))
  end

  def label
    number.to_s + '. ' + full_name.to_s
  end

  def siren_number
    siret_number[0..8]
  end

  def siren
    ActiveSupport::Deprecation.warn('Entity#siren is deprecated. Please use Entity#siren_number instead. This method will be removed in Ekylibre 3.')
    siren_number
  end

  def last_incoming_payment
    incoming_payments.last_updateds.first
  end

  #
  def balance
    amount = 0.0
    amount += incoming_payments.sum(:amount)
    amount -= sales_invoices.sum(:amount)
    amount -= outgoing_payments.sum(:amount)
    amount += purchase_invoices.sum(:amount)
    amount
  end

  def has_another_tracking?(serial, product_id)
    trackings.where('serial=? AND product_id!=? ', serial, product_id).count > 0
  end

  # This method creates automatically an account for the entity for its usage (client, supplier...)
  def account(nature)
    natures = [:client, :supplier]
    conversions = { payer: :client, payee: :supplier }
    nature = nature.to_sym
    nature = conversions[nature] || nature
    unless natures.include?(nature)
      raise ArgumentError, "Unknown nature #{nature.inspect} (#{natures.to_sentence} are accepted)"
    end
    valid_account = send("#{nature}_account")
    if valid_account.nil?
      prefix = Nomen::Account[nature.to_s.pluralize].send(Account.accounting_system)
      if Preference[:use_entity_codes_for_account_numbers]
        number = prefix.to_s + self.number.to_s
        unless valid_account = Account.find_by(number: number)
          valid_account = Account.create(number: number, name: full_name, reconcilable: true)
        end
      else
        suffix = '1'
        suffix = suffix.upper_ascii[0..5].rjust(6, '0')
        account = 1
        # x=Time.zone.now
        i = 0
        until account.nil?
          account = Account.find_by('number LIKE ?', prefix.to_s + suffix.to_s)
          suffix.succ! unless account.nil?
          i += 1
        end
        valid_account = Account.create(number: prefix.to_s + suffix.to_s, name: full_name, reconcilable: true)
      end
      reload.update_column("#{nature}_account_id", valid_account.id)
    end
    valid_account
  end

  def warning
    count = observations.where(importance: 'important').count
    # count += self.balance<0 ? 1 : 0
  end

  def add_event(usage, operator, at = Time.zone.now)
    if operator && item = Nomen::EventNature[usage]
      Event.create!(name: item.human_name, started_at: at, duration: item.default_duration.to_i, participations_attributes: { '0' => { participant_id: id, state: 'informative' }, '1' => { participant_id: operator.id, state: 'accepted' } })
    end
  end

  def default_mail_coordinate
    default_address ? default_address.coordinate : '[NoDefaultEntityAddressError]'
  end

  def link_to!(entity, options = {})
    nature = options[:as] || :undefined
    unless direct_links.actives.where(nature: nature.to_s, linked_id: entity.id).any?
      direct_links.create!(nature: nature.to_s, linked_id: entity.id)
    end
  end

  def maximal_reduction_percentage(computed_at = Time.zone.today)
    Subscription
      .joins("JOIN #{SubscriptionNature.table_name} AS sn ON (#{Subscription.table_name}.nature_id = sn.id) LEFT JOIN #{EntityLink.table_name} AS el ON (el.nature = sn.entity_link_nature AND #{Subscription.table_name}.subscriber_id IN (entity_id, linked_id))")
      .where("? IN (#{Subscription.table_name}.subscriber_id, entity_id, linked_id) AND ? BETWEEN #{Subscription.table_name}.started_at AND #{Subscription.table_name}.stopped_at AND COALESCE(#{Subscription.table_name}.sale_id, 0) NOT IN (SELECT id FROM #{Sale.table_name} WHERE state='estimate')", id, computed_at)
      .maximum(:reduction_percentage).to_f || 0.0
  end

  def picture_path(style = :original)
    picture.path(style)
  end

  def description
    desc = number + '. ' + full_name
    c = default_mail_address
    desc += ' (' + c.mail_line_6.to_s + ')' unless c.nil?
    desc
  end

  # Merge given entity into record. Alls related records of given entity will point on
  # self.
  def merge_with(entity, author = nil)
    raise StandardError, 'Company entity is not mergeable' if entity.of_company?
    Ekylibre::Record::Base.transaction do
      # EntityAddress
      threads = EntityAddress.unscoped.where(entity_id: id).uniq.pluck(:thread)
      other_threads = EntityAddress.unscoped.where(entity_id: entity.id).uniq.pluck(:thread)
      other_threads.each do |thread|
        thread.succ! while threads.include?(thread)
        threads << thread
        EntityAddress.unscoped.where(entity_id: entity.id).update_all(thread: thread, by_default: false)
      end

      # Relations with DB approach to prevent missing reflection
      connection = self.class.connection
      base_class = self.class.base_class
      base_model = base_class.name.underscore.to_sym
      models_set = ([base_class] + base_class.descendants)
      models_group = '(' + models_set.map do |model|
        "'#{model.name}'"
      end.join(', ') + ')'
      Ekylibre::Schema.tables.each do |table, columns|
        columns.each do |_name, column|
          next unless column.references
          if column.references.is_a?(String) # Polymorphic
            connection.execute("UPDATE #{table} SET #{column.name}=#{id} WHERE #{column.name}=#{entity.id} AND #{column.references} IN #{models_group}")
          elsif column.references == base_model # Straight
            connection.execute("UPDATE #{table} SET #{column.name}=#{id} WHERE #{column.name}=#{entity.id}")
          end
        end
      end

      # Update attributes
      [:currency, :country, :last_name, :first_name, :activity_code, :description, :born_at, :dead_at, :deliveries_conditions, :first_met_at, :meeting_origin, :proposer, :siret_number, :supplier_account, :client_account, :vat_number, :language, :authorized_payments_count].each do |attr|
        send("#{attr}=", entity.send(attr)) if send(attr).blank?
      end
      if entity.picture.file? && !picture.file?
        self.picture = File.open(entity.picture.path(:original))
      end

      # Update custom fields
      self.custom_fields ||= {}
      entity.custom_fields ||= {}
      Entity.custom_fields.each do |custom_field|
        attr = custom_field.column_name
        if self.custom_fields[attr].blank? && entity.custom_fields[attr].present?
          self.custom_fields[attr] = entity.custom_fields[attr]
        end
      end

      save!

      # Add observation
      content = "Merged entity (ID=#{entity.id}):\n"
      for attr, value in entity.attributes.sort
        value = entity.send(attr).to_s
        content << "  - #{Entity.human_attribute_name(attr)} : #{value}\n" unless value.blank?
      end
      Entity.custom_fields.each do |custom_field|
        value = entity.custom_fields[custom_field.column_name].to_s
        content << "  - #{custom_field.name} : #{value}\n" unless value.blank?
      end

      observations.create!(content: content, importance: 'normal', author: author)

      # Remove doublon
      entity.destroy
    end
  end

  def self.best_clients(limit = -1)
    clients.sort_by { |client| -client.sales.count }[0...limit]
  end

  def self.importable_columns
    columns = []
    columns << [tc('import.dont_use'), 'special-dont_use']
    columns << [tc('import.generate_string_custom_field'), 'special-generate_string_custom_field']
    # columns << [tc("import.generate_choice_custom_field"), "special-generate_choice_custom_field"]
    cols = Entity.content_columns.delete_if { |c| [:active, :full_name, :lock_version, :updated_at, :created_at].include?(c.name.to_sym) || c.type == :boolean }.collect(&:name)
    columns += cols.collect { |c| [Entity.model_name.human + '/' + Entity.human_attribute_name(c), 'entity-' + c] }.sort
    cols = EntityAddress.content_columns.collect(&:name).delete_if { |c| [:number, :started_at, :stopped_at, :deleted, :address, :by_default, :closed_at, :lock_version, :active, :updated_at, :created_at].include?(c.to_sym) } + %w(item_6_city item_6_code)
    columns += cols.collect { |c| [EntityAddress.model_name.human + '/' + EntityAddress.human_attribute_name(c), 'address-' + c] }.sort
    columns += %w(name abbreviation).collect { |c| [EntityNature.model_name.human + '/' + EntityNature.human_attribute_name(c), 'entity_nature-' + c] }.sort
    # columns += ["name"].collect{|c| [Catalog.model_name.human+"/"+Catalog.human_attribute_name(c), "product_price_listing-"+c]}.sort
    columns += CustomField.where("nature in ('string')").collect { |c| [CustomField.model_name.human + '/' + c.name, 'custom_field-id' + c.id.to_s] }.sort
    columns
  end

  # def self.exportable_columns
  #   columns = []
  #   columns += Entity.content_columns.collect{|c| [Entity.model_name.human+"/"+Entity.human_attribute_name(c.name), "entity-"+c.name]}.sort
  #   columns += EntityAddress.content_columns.collect{|c| [EntityAddress.model_name.human+"/"+EntityAddress.human_attribute_name(c.name), "address-"+c.name]}.sort
  #   columns += EntityNature.content_columns.collect{|c| [EntityNature.model_name.human+"/"+EntityNature.human_attribute_name(c.name), "entity_nature-"+c.name]}.sort
  #   columns += Catalog.content_columns.collect{|c| [Catalog.model_name.human+"/"+Catalog.human_attribute_name(c.name), "product_price_listing-"+c.name]}.sort
  #   columns += CustomField.all.collect{|c| [CustomField.model_name.human+"/"+c.name, "custom_field-id"+c.id.to_s]}.sort
  #   return columns
  # end

  # def self.import(file, cols, options={})
  #   sheet = Ekylibre::CSV.open(file)
  #   header = sheet.shift # header
  #   problems = {}
  #   item_index = 1
  #   code  = "ActiveRecord::Base.transaction do\n"
  #   # unless cols[:entity_nature].is_a? Hash
  #     # code += "  nature = EntityNature.where('title=? OR name=?', '-', '-').first\n"
  #     # code += "  nature = EntityNature.create!(:title => '', :name => '-', :physical => false, :in_name => false, :active => true) unless nature\n"
  #   # end
  #   unless cols[:product_price_listing].is_a? Hash
  #     code += "  sale_catalog = Catalog.where('name=? or code=?', '-', '-').first\n"
  #     code += "  sale_catalog = Catalog.create!(:name => '-', by_default: false) unless sale_catalog\n"
  #   end
  #   for k, v in (cols[:special]||{}).select{|k, v| v == :generate_string_custom_field}
  #     code += "  custom_field_#{k} = CustomField.create!(:name => #{header[k.to_i].inspect}, :active => true, :length_max => 65536, :nature => 'string', :required => false)\n"
  #   end
  #   code += "  while item = sheet.shift\n"
  #   code += "    item_index += 1\n"
  #   code += "    next if #{options[:ignore].collect{|x| x.to_i}.inspect}.include?(item_index)\n" if options[:ignore]
  #   # if cols[:entity_nature].is_a? Hash
  #     # code += "    nature = EntityNature.where("+cols[:entity_nature].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+").first\n"
  #     # code += "    begin\n"
  #     # code += "      nature = EntityNature.create!("+cols[:entity_nature].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+")\n"
  #     # code += "    rescue\n"
  #     # code += "      nature = EntityNature.where('abbreviation=? OR name=?', '-', '-').first\n"
  #     # code += "      nature = EntityNature.create!(:abbreviation => '-', :name => '-', :physical => false, :in_name => false, :active => true) unless nature\n"
  #     # code += "    end unless nature\n"
  #   # end
  #   if cols[:product_price_listing].is_a? Hash
  #     code += "    sale_catalog = Catalog.where("+cols[:product_price_listing].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+").first\n"
  #     code += "    begin\n"
  #     code += "      sale_catalog = Catalog.create!("+cols[:product_price_listing].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+")\n"
  #     code += "    rescue\n"
  #     code += "      sale_catalog = Catalog.where('name=? or code=?', '-', '-').first\n"
  #     code += "      sale_catalog = Catalog.create!(:name => '-', by_default: false) unless sale_catalog\n"
  #     code += "    end unless sale_catalog\n"
  #   end

  #   code += "    entity = Entity.build("+cols[:entity].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+", :nature => nature, :sale_catalog_id => sale_catalog.id, :language => #{self.of_company.language.inspect}, :client => true)\n"
  #   code += "    if entity.save\n"
  #   if cols[:address].is_a? Hash
  #     code += "      address = entity.addresses.build("+cols[:address].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+")\n"
  #     code += "      unless address.save\n"
  #     code += "        problems[item_index.to_s] ||= []\n"
  #     code += "        problems[item_index.to_s] += address.errors.full_messages\n"
  #     code += "      end\n"
  #   end
  #   for k, v in (cols[:special]||{}).select{|k,v| v == :generate_string_custom_field}
  #     code += "      datum = entity.custom_field_data.build(:custom_field_id => custom_field_#{k}.id, :string_value => item[#{k}])\n"
  #     code += "      unless datum.save\n"
  #     code += "        problems[item_index.to_s] ||= []\n"
  #     code += "        problems[item_index.to_s] += datum.errors.full_messages\n"
  #     code += "      end\n"
  #   end
  #   for k, v in cols[:custom_field]||{}
  #     if custom_field = CustomField.find_by_id(k.to_s[2..-1].to_i)
  #       if custom_field.nature == 'string'
  #         code += "      datum = entity.custom_field_data.build(:custom_field_id => #{custom_field.id}, :string_value => item[#{k}])\n"
  #         code += "      unless datum.save\n"
  #         code += "        problems[item_index.to_s] ||= []\n"
  #         code += "        problems[item_index.to_s] += datum.errors.full_messages\n"
  #         code += "      end\n"
  #         # elsif custom_field.nature == 'choice'
  #         #   code += "    co = entity.addresses.create("+cols[:address].collect{|k,v| ":#{v} => item[#{k}]"}.join(', ')+")\n" if cols[:address].is_a? Hash
  #       end
  #     end
  #   end
  #   code += "    else\n"
  #   code += "      problems[item_index.to_s] ||= []\n"
  #   code += "      problems[item_index.to_s] += entity.errors.full_messages\n"
  #   code += "    end\n"
  #   code += "  end\n"
  #   code += "  raise ActiveRecord::Rollback\n" unless options[:no_simulation]
  #   code += "end\n"
  #   # list = code.split("\n"); list.each_index{|x| puts((x+1).to_s.rjust(4)+": "+list[x])}
  #   eval(code)
  #   return {:errors => problems, :items_count => item_index-1}
  # end

  def self.export(_options = {})
    # entities = Entity.where(options)
    csv_string = Ekylibre::CSV.generate do |csv|
      csv << ['Code', 'Type', 'Catégorie', 'Nom', 'Prénom', 'Dest-Service', 'Bat.-Res.-ZI', 'N° et voie', 'Lieu dit', 'Code Postal', 'Ville', 'Téléphone', 'Mobile', 'Fax', 'Email', 'Site Web', 'Taux de réduction']
      each do |entity|
        address = EntityAddress.find_by(entity_id: entity.id, by_default: true, deleted_at: nil)
        item = []
        item << ["'" + entity.number.to_s, entity.nature.name, entity.sale_catalog.name, entity.name, entity.first_name]
        item << if !address.nil?
                  [address.item_2, address.item_3, address.item_4, address.item_5, address.item_6_code, address.item_6_city, address.phone, address.mobile, address.fax, address.email, address.website]
                else
                  ['', '', '', '', '', '', '', '', '', '', '']
      end
        item << [entity.reduction_percentage.to_s.tr('.', ',')]
        csv << item.flatten
      end
    end
    csv_string
end
end
