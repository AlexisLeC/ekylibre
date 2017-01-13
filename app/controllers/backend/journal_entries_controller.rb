# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class JournalEntriesController < Backend::BaseController
    manage_restfully only: [:show, :destroy]

    unroll

    list(children: :items, order: { created_at: :desc }, per_page: 10) do |t|
      t.action :edit, if: :updateable?
      t.action :destroy, if: :destroyable?
      t.column :number, url: true, children: :name
      t.column :printed_on, datatype: :date, children: false
      t.column :state_label
      t.column :real_debit,  currency: :real_currency
      t.column :real_credit, currency: :real_currency
      t.column :real_balance, currency: :real_currency
      t.column :debit,  currency: true, hidden: true
      t.column :credit, currency: true, hidden: true
      t.column :absolute_debit,  currency: :absolute_currency, hidden: true
      t.column :absolute_credit, currency: :absolute_currency, hidden: true
    end

    list(:items, model: :journal_entry_items, conditions: { entry_id: 'params[:id]'.c }, order: :position) do |t|
      t.column :name
      t.column :account, url: true
      t.column :account_number, through: :account, label_method: :number, url: true, hidden: true
      t.column :account_name, through: :account, label_method: :name, url: true, hidden: true
      t.column :bank_statement, url: true, hidden: true
      # t.column :number, through: :account, url: true
      # t.column :name, through: :account, url: true
      # t.column :number, through: :bank_statement, url: true, hidden: true
      t.column :real_debit,  currency: :real_currency
      t.column :real_credit, currency: :real_currency
      t.column :debit,  currency: true, hidden: true
      t.column :credit, currency: true, hidden: true
      t.column :balance, currency: true, hidden: true
      t.column :absolute_debit,  currency: :absolute_currency, hidden: true
      t.column :absolute_credit, currency: :absolute_currency, hidden: true
      t.column :activity_budget, hidden: true
      t.column :team, hidden: true
      t.column :product_item_to_tax_label, label: :tax_label, hidden: true
    end

    def index
      redirect_to controller: :journals, action: :index
    end

    def new
      if params[:duplicate_of]
        @journal_entry = JournalEntry.find_by(id: params[:duplicate_of])
                                     .deep_clone(include: :items, except: :number)
        @journal = @journal_entry.journal
      else
        @journal_entry = JournalEntry.new
        @journal_entry.printed_on = params[:printed_on] || Time.zone.today
        @journal_entry.real_currency_rate = params[:exchange_rate].to_f
        @journal = Journal.find_by(id: params[:journal_id])
      end
      if @journal
        @journal_entry.journal = @journal
        t3e @journal.attributes
      end
      if request.xhr?
        render(partial: 'backend/journal_entries/items_form', locals: { items: @journal_entry.items })
      end
    end

    def create
      return unless @journal = find_and_check(:journal, params[:journal_id])
      items = params[:items].each_with_object({}) { |pair, hash| hash[pair.first] = pair.last.except(:id) }
      @journal_entry = @journal.entries.build(permitted_params.merge(items_attributes: items.values).permit!)
      @journal_entry_items = (params[:items] || {}).values
      # raise @journal_entry_items.inspect
      if @journal_entry.save
        if params[:affair_id]
          affair = Affair.find_by(id: params[:affair_id])
          if affair
            Regularization.create!(affair: affair, journal_entry: @journal_entry)
          end
        end
        if @journal_entry.number == params[:theoretical_number]
          notify_success(:journal_entry_has_been_saved, number: @journal_entry.number)
        else
          notify_success(:journal_entry_has_been_saved_with_a_new_number, number: @journal_entry.number)
        end
        redirect_to params[:redirect] || { controller: :journal_entries, action: :new, journal_id: @journal.id, exchange_rate: @journal_entry.real_currency_rate, printed_on: @journal_entry.printed_on }
        return
      end
      @journal_entry.errors.messages.except(:printed_on).each do |field, messages|
        next if /items\./ =~ field
        messages.each { |m| notify_error_now "#{JournalEntry.human_attribute_name(field)}: #{m.capitalize}" }
      end
      t3e @journal.attributes
    end

    def edit
      return unless @journal_entry = find_and_check
      unless @journal_entry.updateable?
        notify_error(:journal_entry_already_validated)
        redirect_to_back
        return
      end
      @journal = @journal_entry.journal
      t3e @journal_entry.attributes
    end

    def update
      return unless @journal_entry = find_and_check
      unless @journal_entry.updateable?
        notify_error(:journal_entry_already_validated)
        redirect_to_back
        return
      end
      @journal = @journal_entry.journal
      items = params[:items].each_with_object({}) do |pair, hash|
        attributes = pair.last[:id].to_i > 0 ? pair.last : pair.last.except(:id)
        hash[pair.first] = attributes
      end
      @journal_entry.attributes = permitted_params.merge(items_attributes: items.values).permit!
      @journal_entry_items = (params[:items] || {}).values
      if @journal_entry.save
        redirect_to params[:redirect] || { action: :show, id: @journal_entry.id }
        return
      end
      @journal_entry.errors.messages.except(:printed_on).each do |field, messages|
        next if /items\./ =~ field
        messages.each { |m| notify_error_now "#{JournalEntry.human_attribute_name(field)}: #{m.capitalize}" }
      end
      t3e @journal_entry.attributes
    end

    def toggle_autocompletion
      set_preference = params.require(:autocompletion)
      choice = (set_preference == 'true')
      return unless Preference.set!(:entry_autocompletion, choice)
      respond_to do |format|
        format.json { render json: { status: :success, preference: choice } }
      end
    end
  end
end
