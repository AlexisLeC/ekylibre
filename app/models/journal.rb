# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2015 Brice Texier, David Joulin
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
# == Table: journals
#
#  closed_on        :date             not null
#  code             :string(4)        not null
#  created_at       :datetime         not null
#  creator_id       :integer
#  currency         :string(3)        not null
#  id               :integer          not null, primary key
#  lock_version     :integer          default(0), not null
#  name             :string(255)      not null
#  nature           :string(30)       not null
#  updated_at       :datetime         not null
#  updater_id       :integer
#  used_for_affairs :boolean          not null
#  used_for_gaps    :boolean          not null
#


class Journal < Ekylibre::Record::Base
  attr_readonly :currency
  has_many :cashes
  has_many :entry_items, class_name: "JournalEntryItem", inverse_of: :journal
  has_many :entries, class_name: "JournalEntry", inverse_of: :journal
  enumerize :nature, in: [:sales, :purchases, :bank, :forward, :various, :cash], default: :various, predicates: true
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_date :closed_on, allow_blank: true, on_or_after: Date.civil(1, 1, 1)
  validates_length_of :currency, allow_nil: true, maximum: 3
  validates_length_of :code, allow_nil: true, maximum: 4
  validates_length_of :nature, allow_nil: true, maximum: 30
  validates_length_of :name, allow_nil: true, maximum: 255
  validates_inclusion_of :used_for_affairs, :used_for_gaps, in: [true, false]
  validates_presence_of :closed_on, :code, :currency, :name, :nature
  #]VALIDATORS]
  validates_uniqueness_of :code
  validates_uniqueness_of :name
  validates_format_of :code, with: /\A[0-9A-Z]+\z/

  selects_among_all :used_for_affairs, :used_for_gaps, if: :various?

  scope :used_for, lambda { |nature|
    unless self.nature.values.include?(nature.to_s)
      raise ArgumentError, "Journal#used_for must be one of these: #{self.nature.values.join(', ')}"
    end
    where(nature: nature.to_s)
  }
  scope :opened_on, lambda { |at|
    where(arel_table[:closed_on].lteq(at))
  }
  scope :sales,     -> { where(nature: "sales") }
  scope :purchases, -> { where(nature: "purchases") }
  scope :banks,     -> { where(nature: "bank") }
  scope :forwards,  -> { where(nature: "forward") }
  scope :various,   -> { where(nature: "various") }
  scope :cashes,    -> { where(nature: "cashes") }
  scope :banks_or_cashes, -> { where(nature: "cashes").or.where(nature: "bank") }

  before_validation(on: :create) do
    if year = FinancialYear.first_of_all
      self.closed_on ||= (year.started_on - 1).end_of_day
    end
    self.closed_on ||= Time.new(1899, 12, 31).end_of_month
  end

  before_validation do
    self.name = self.nature.l if self.name.blank? and self.nature
    if eoc = Entity.of_company
      self.currency ||= eoc.currency
    end
    if self.code.blank?
      self.code = self.nature.l
    end
    self.code = self.code.codeize[0..3]
  end

  validate do
    if self.closed_on and FinancialYear.find_by(started_on: self.closed_on + 1).blank?
      if self.closed_on != self.closed_on.end_of_month
        errors.add(:closed_on, :end_of_month, closed_on: self.closed_on.l)
      end
    end
    unless self.code.blank?
      if self.others.find_by(code: self.code.to_s[0..3])
        errors.add(:code, :taken)
      end
    end
  end

  protect(on: :destroy) do
    self.entries.any? or self.entry_items.any? or self.cashes.any?
  end



  # Returns the default journal from preferences
  # Creates the journal if not exists
  def self.get(name)
    name = name.to_s
    pref_name  = "#{name}_journal"
    raise ArgumentError.new("Unvalid journal name: #{name.inspect}") unless self.class.preferences_reference.has_key? pref_name
    unless journal = self.preferred(pref_name)
      journal = self.journals.find_by_nature(name)
      journal = self.journals.create!(:name => tc("default.journals.#{name}"), nature: name, currency: self.default_currency) unless journal
      self.prefer!(pref_name, journal)
    end
    return journal
  end



  #
  def closable?(closed_on=nil)
    closed_on ||= Date.today
    self.class.where(:id => self.id).update_all(:closed_on => Date.civil(1900, 12, 31)) if self.closed_on.nil?
    self.reload
    return false unless (closed_on << 1).end_of_month > self.closed_on
    return true
  end

  def closures(noticed_on=nil)
    noticed_on ||= Date.today
    array, date = [], (self.closed_on+1).end_of_month
    while date < noticed_on
      array << date
      date = (date+1).end_of_month
    end
    return array
  end

  # this method closes a journal.
  def close(closed_on)
    errors.add(:closed_on, :end_of_month) if self.closed_on != self.closed_on.end_of_month
    errors.add(:closed_on, :draft_entry_items, :closed_on => closed_on.l) if self.entry_items.joins("JOIN #{JournalEntry.table_name} AS journal_entries ON (entry_id=journal_entries.id)").where(:state => :draft).where(printed_on: (self.closed_on+1)..closed_on).any?
    return false unless errors.empty?
    ActiveRecord::Base.transaction do
      self.entries.where(printed_on: (self.closed_on+1)..closed_on).find_each do |entry|
        entry.close
      end
      self.update_column(:closed_on, closed_on)
    end
    return true
  end


  def reopenable?
    return false unless self.reopenings.any?
    return true
  end

  def reopenings
    year = FinancialYear.current
    return [] if year.nil?
    array, date = [], year.started_on-1
    while date < self.closed_on
      array << date
      date = (date+1).end_of_month
    end
    return array
  end

  def reopen(closed_on)
    ActiveRecord::Base.transaction do
      for entry in self.entries.where(printed_on: (closed_on+1)..self.closed_on)
        entry.reopen
      end
      self.update_column(:closed_on, closed_on)
    end
    return true
  end

  # Takes the very last created entry in the journal to generate the entry number
  def next_number
    entry = self.entries.order(id: :desc).first
    number = entry ? entry.number : self.code.to_s.upcase + "000000"
    number.gsub!(/(9+)\z/, '0\1') if number.match(/[^\d]9+\z/)
    number.succ!
    while self.entries.where(number: number).any?
      number.gsub!(/(9+)\z/, '0\1') if number.match(/[^\d]9+\z/)
      number.succ!
    end
    return number
  end

  # this method searches the last entries according to a number.
  def last_entries(period, count = 30)
    period.entries.order("LPAD(number, 20, '0') DESC").limit(count)
  end


  def entry_items_between(started_on, stopped_on)
    self.entry_items.joins("JOIN #{JournalEntry.table_name} AS journal_entries ON (journal_entries.id=entry_id)").where(printed_on: started_on..stopped_on).order("printed_on, journal_entries.id, journal_entry_items.id")
  end

  def entry_items_calculate(column, started_on, stopped_on, operation=:sum)
    column = (column == :balance ? "#{JournalEntryItem.table_name}.real_debit - #{JournalEntryItem.table_name}.real_credit" : "#{JournalEntryItem.table_name}.real_#{column}")
    self.entry_items.joins("JOIN #{JournalEntry.table_name} AS journal_entries ON (journal_entries.id=entry_id)").where(printed_on: started_on..stopped_on).calculate(operation, column)
  end


  # Compute a balance with many options
  # * :started_on Use journal entries printed on after started_on
  # * :stopped_on Use journal entries printed on before stopped_on
  # * :draft      Use draft journal entry_items
  # * :confirmed  Use confirmed journal entry_items
  # * :closed     Use closed journal entry_items
  # * :accounts   Select ranges of accounts
  # * :centralize Select account's prefixe which permits to centralize
  def self.balance(options={})
    conn = ActiveRecord::Base.connection
    journal_entry_items, journal_entries, accounts = "jel", "je", "a"

    journal_entries_states = ' AND ' + JournalEntry.state_condition(options[:states], journal_entries)

    # account_range = ' AND ' + Account.range_condition(options[:accounts], accounts)
    account_range = ' AND ' + Account.range_condition(options[:accounts], accounts)

    # raise StandardError.new(options[:centralize].to_s.strip.split(/[^A-Z0-9]+/).inspect)
    centralize = options[:centralize].to_s.strip.split(/[^A-Z0-9]+/) # .delete_if{|x| x.blank? or !expr.match(valid_expr)}
    options[:centralize] = centralize.join(" ")
    centralized = centralize.collect{|c| "#{accounts}.number LIKE #{conn.quote(c+'%')}"}.join(" OR ")

    from_where  = " FROM #{JournalEntryItem.table_name} AS #{journal_entry_items} JOIN #{Account.table_name} AS #{accounts} ON (account_id=#{accounts}.id) JOIN #{JournalEntry.table_name} AS #{journal_entries} ON (entry_id=#{journal_entries}.id)"
    from_where += " WHERE "+JournalEntry.period_condition(options[:period], options[:started_on], options[:stopped_on], journal_entries)

    # Total
    items = []
    query  = "SELECT '', -1, sum(COALESCE(#{journal_entry_items}.debit, 0)), sum(COALESCE(#{journal_entry_items}.credit, 0)), sum(COALESCE(#{journal_entry_items}.debit, 0)) - sum(COALESCE(#{journal_entry_items}.credit, 0)), '#{'Z'*16}' AS skey"
    query << from_where
    query << journal_entries_states
    query << account_range
    items += conn.select_rows(query)

    # Sub-totals
    for name, value in options.select{|k, v| k.to_s.match(/^level_\d+$/) and v.to_i == 1}
      level = name.split(/\_/)[-1].to_i
      query  = "SELECT SUBSTR(#{accounts}.number, 1, #{level}) AS subtotal, -2, sum(COALESCE(#{journal_entry_items}.debit, 0)), sum(COALESCE(#{journal_entry_items}.credit, 0)), sum(COALESCE(#{journal_entry_items}.debit, 0)) - sum(COALESCE(#{journal_entry_items}.credit, 0)), SUBSTR(#{accounts}.number, 1, #{level})||'#{'Z'*(16-level)}' AS skey"
      query << from_where
      query << journal_entries_states
      query << account_range
      query << " AND LENGTH(#{accounts}.number) >= #{level}"
      query << " GROUP BY subtotal"
      items += conn.select_rows(query)
    end

    # NOT centralized accounts (default)
    query  = "SELECT #{accounts}.number, #{accounts}.id AS account_id, sum(COALESCE(#{journal_entry_items}.debit, 0)), sum(COALESCE(#{journal_entry_items}.credit, 0)), sum(COALESCE(#{journal_entry_items}.debit, 0)) - sum(COALESCE(#{journal_entry_items}.credit, 0)), #{accounts}.number AS skey"
    query << from_where
    query << journal_entries_states
    query << account_range
    query << " AND NOT #{centralized}" unless centralize.empty?
    query << " GROUP BY #{accounts}.id, #{accounts}.number"
    query << " ORDER BY #{accounts}.number"
    items += conn.select_rows(query)

    # Centralized accounts
    for prefix in centralize
      query  = "SELECT SUBSTR(#{accounts}.number, 1, #{prefix.size}) AS centralize, -3, sum(COALESCE(#{journal_entry_items}.debit, 0)), sum(COALESCE(#{journal_entry_items}.credit, 0)), sum(COALESCE(#{journal_entry_items}.debit, 0)) - sum(COALESCE(#{journal_entry_items}.credit, 0)), #{conn.quote(prefix)} AS skey"
      query << from_where
      query << journal_entries_states
      query << account_range
      query << " AND #{accounts}.number LIKE #{conn.quote(prefix+'%')}"
      query << " GROUP BY centralize"
      items += conn.select_rows(query)
    end

    return items.sort{|a,b| a[5] <=> b[5]}
  end


end

