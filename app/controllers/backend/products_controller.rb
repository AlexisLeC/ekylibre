# == License
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class ProductsController < Backend::BaseController
    manage_restfully t3e: { nature: :nature_name }, subclass_inheritance: true, multipart: true
    manage_restfully_picture

    respond_to :pdf, :odt, :docx, :xml, :json, :html, :csv

    before_action :check_variant_availability, only: :new

    unroll :name, :number, :work_number, :identification_number # , 'population:!', 'unit_name:!'

    # params:
    #   :q Text search
    #   :working_set
    def self.list_conditions
      code = search_conditions(products: [:name, :work_number, :number, :description, :uuid], product_nature_variants: [:name]) + " ||= []\n"
      code << "unless params[:working_set].blank?\n"
      code << "  item = Nomen::WorkingSet.find(params[:working_set])\n"
      code << "  c[0] << \" AND products.nature_id IN (SELECT id FROM product_natures WHERE \#{WorkingSet.to_sql(item.expression)})\"\n"
      code << "end\n"
      code << "if params[:s] == 'available'\n"
      code << "  c[0] << ' AND #{Product.table_name}.dead_at IS NULL'\n"
      code << "elsif params[:s] == 'consume'\n"
      code << "  c[0] << ' AND #{Product.table_name}.dead_at IS NOT NULL'\n"
      code << "end\n"
      code << "if params[:period].to_s != 'all'\n"
      code << "  started_on = params[:started_on]\n"
      code << "  stopped_on = params[:stopped_on]\n"
      code << "  c[0] << ' AND #{Product.table_name}.born_at BETWEEN ? AND ?'\n"
      code << "  c << started_on\n"
      code << "  c << stopped_on\n"
      code << "  if params[:s] == 'consume'\n"
      code << "    c[0] << ' AND #{Product.table_name}.dead_at BETWEEN ? AND ?'\n"
      code << "    c << started_on\n"
      code << "    c << stopped_on\n"
      code << "  end\n"
      code << "end\n"
      code << "c\n"
      code.c
    end

    list(conditions: list_conditions) do |t|
      t.action :edit
      t.action :destroy, if: :destroyable?
      t.column :number, url: true
      t.column :work_number
      t.column :name, url: true
      t.column :variant, url: true
      t.column :variety
      t.column :population
      t.column :unit_name
      t.column :container, url: true
      t.column :description
    end

    # Lists contained products of the current product
    list(:contained_products, model: :product_localizations, conditions: { container_id: 'params[:id]'.c, stopped_at: nil }, order: { started_at: :desc }) do |t|
      t.column :product, url: true
      t.column :nature, hidden: true
      t.column :intervention, url: true
      t.column :started_at
      t.column :stopped_at, hidden: true
    end

    # Lists carried linkages of the current product
    list(:carried_linkages, model: :product_linkages, conditions: { carrier_id: 'params[:id]'.c }, order: { started_at: :desc }) do |t|
      t.column :carried, url: true
      t.column :point
      t.column :nature
      t.column :intervention, url: true
      t.column :started_at, through: :intervention, datatype: :datetime
      t.column :stopped_at, through: :intervention, datatype: :datetime
    end

    # Lists carrier linkages of the current product
    list(:carrier_linkages, model: :product_linkages, conditions: { carried_id: 'params[:id]'.c }, order: { started_at: :desc }) do |t|
      t.column :carrier, url: true
      t.column :point
      t.column :nature
      t.column :intervention, url: true
      t.column :started_at
      t.column :stopped_at
    end

    # Lists groups of the current product
    list(:inspections, conditions: { product_id: 'params[:id]'.c }, order: { sampled_at: :desc }) do |t|
      t.column :number, url: true
      t.column :position
      t.column :sampled_at
      # t.column :item_count
      # t.column :net_mass, datatype: :measure
    end

    # Lists groups of the current product
    list(:groups, model: :product_memberships, conditions: { member_id: 'params[:id]'.c }, order: { started_at: :desc }) do |t|
      t.column :group, url: true
      t.column :intervention, url: true
      t.column :started_at
      t.column :stopped_at
    end

    # Lists issues of the current product
    list(:issues, conditions: { target_id: 'params[:id]'.c, target_type: 'Product' }, order: { observed_at: :desc }) do |t|
      t.action :new, url: { controller: :interventions, issue_id: 'RECORD.id'.c, id: nil }
      t.column :nature, url: true
      t.column :observed_at
      t.status
    end

    # Lists intervention product parameters of the current product
    list(:intervention_product_parameters, conditions: { product_id: 'params[:id]'.c }, order: 'interventions.started_at DESC') do |t|
      t.column :intervention, url: true
      # t.column :roles, hidden: true
      t.column :name, sort: :reference_name
      t.column :started_at, through: :intervention, datatype: :datetime
      t.column :stopped_at, through: :intervention, datatype: :datetime, hidden: true
      t.column :human_activities_names, through: :intervention
      # t.column :intervention_activities
      t.column :human_working_duration, through: :intervention
      t.column :human_working_zone_area, through: :intervention
    end

    # Lists members of the current product
    list(:members, model: :product_memberships, conditions: { group_id: 'params[:id]'.c }, order: :started_at) do |t|
      t.column :member, url: true
      t.column :intervention, url: true
      t.column :started_at
      t.column :stopped_at
    end

    # Lists localizations of the current product
    list(:places, model: :product_localizations, conditions: { product_id: 'params[:id]'.c }, order: { started_at: :desc }) do |t|
      t.column :nature
      t.column :container, url: true
      t.column :intervention, url: true
      t.column :started_at
      t.column :stopped_at, hidden: true
    end

    # Lists readings of the current product
    list(:readings, model: :product_readings, conditions: { product_id: 'params[:id]'.c }, order: { created_at: :desc }) do |t|
      t.column :indicator_name
      t.column :read_at
      t.column :value
    end

    # Lists target distributions of the current product
    list(:target_distributions, model: :target_distributions, conditions: { target_id: 'params[:id]'.c }, order: { started_at: :asc }) do |t|
      t.column :activity
      t.column :activity_production
      t.column :started_at
      t.column :stopped_at
    end

    # Returns value of an indicator
    def take
      return unless @product = find_and_check
      indicator = Nomen::Indicator.find(params[:indicator])
      unless indicator
        head :unprocessable_entity
        return
      end

      value = @product.get(indicator)
      if indicator.datatype == :measure
        if unit = Nomen::Unit[params[:unit]]
          value = value.convert(unit)
        end
        value = { unit: value.unit, value: value.to_d.round(4) }
      elsif [:integer, :decimal].include? indicator.datatype
        value = { value: value.to_d.round(4) }
      end
      render json: value
    end

    protected

    def check_variant_availability
      unless ProductNatureVariant.of_variety(controller_name.to_s.underscore.singularize).any?
        redirect_to new_backend_product_nature_path
        return false
      end
    end
  end
end
