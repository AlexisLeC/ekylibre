# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2013 Brice Texier, David Joulin
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
  class ManureManagementPlansController < Backend::BaseController

    helper ManureManagementPlanHelper
    manage_restfully redirect_to: "{action: :edit, id: 'id'.c}".c

    respond_to :pdf, :odt, :docx, :xml, :json, :html, :csv

    unroll

    list do |t|
      t.action :edit
      t.action :destroy
      t.column :name, url: true
      t.column :campaign, url: true
      t.column :recommender, url: true
      t.column :opened_at, hidden: true
      t.column :annotation
    end

    list :zones, model: :manure_management_plan_zones, conditions: { plan_id: 'params[:id]'.c } do |t|
      t.column :activity, url: true
      t.column :cultivable_zone, url: true
      t.column :nitrogen_need
      t.column :absorbed_nitrogen_at_opening, hidden: true
      t.column :mineral_nitrogen_at_opening, hidden: true
      t.column :humus_mineralization, hidden: true
      t.column :meadow_humus_mineralization, hidden: true
      t.column :previous_cultivation_residue_mineralization, hidden: true
      t.column :intermediate_cultivation_residue_mineralization, hidden: true
      t.column :irrigation_water_nitrogen, hidden: true
      t.column :organic_fertilizer_mineral_fraction, hidden: true
      t.column :nitrogen_at_closing, hidden: true
      t.column :soil_production, hidden: true
      t.column :maximum_nitrogen_input
      t.column :nitrogen_input
    end

    def new
      #check if manure_management_plan already exists
      mmp = ManureManagementPlan.of_campaign(current_campaign).first

      redirect_to action: :edit, id: mmp.id unless mmp.nil?
      need_soil_nature_form = false
      @manure_management_plan = ManureManagementPlan.new(:campaign => current_campaign,
                                                         :opened_at => Time.new(current_campaign.harvest_year,2,1).to_datetime,
                                                         :recommender_id => current_user.person_id,
                                                         :name => "Fumure " + current_campaign["harvest_year"].to_s)
      ActivityProduction.of_campaign(current_campaign).of_activity_families("plant_farming").each do |activity_production|
         admin_area = Nomen::AdministrativeArea.find_by(code: activity_production.support.administrative_area)
         admin_area_name = admin_area.name unless admin_area.nil?
         zone = @manure_management_plan.zones.new(
            :activity_production => activity_production,
            :soil_nature => activity_production.support.estimated_soil_nature,
            :cultivation_variety => activity_production.cultivation_variety,
            :administrative_area => admin_area_name,
         )
         if zone.soil_nature.nil? then need_soil_nature_form = true end
      end
      render :create unless need_soil_nature_form
    end

    def create
      manure_natures = permitted_params.delete("manure_natures").reject{|nature| nature.empty? || nature.nil? }
      @manure_management_plan = ManureManagementPlan.new(permitted_params)
      mmp_natures = []
      manure_natures.each do |manure_nature|
        mmp_nature = ManureManagementPlanNature.new(supply_nature: manure_nature)
        mmp_natures.push(mmp_nature)
        @manure_management_plan.zones.each do |zone|
           ManureApproachApplication.create!(manure_management_plan_zone: zone,
                                             manure_management_plan_nature: mmp_nature,
                                             supply_nature: mmp_nature.supply_nature,
                                             parameters: {},
                                             results: {},
                                             approach_id: ManureApproachApplication.most_relevant_approach(zone.support_shape, mmp_nature.supply_nature))
         end
      end
      @manure_management_plan.manure_natures = mmp_natures
      @manure_management_plan.save

      redirect_to action: :edit, id: @manure_management_plan.id
    end

    def compute
      @manure_management_plan = ManureManagementPlan.of_campaign(current_campaign).first

      @manure_management_plan.zones.each do |zone|
        approach_applications = zone.manure_approach_applications
        approach_applications.each do |approach_app|
          unless approach_app.approach.nil?
            approach = Calculus::ManureManagementPlan::Approach.build_approach(approach_app)
            res1 = approach.yields_procedure
            res2 = approach.needs_procedure
          end
        end
      end

    end

    def update_question
      geojson = params['shape']
      rgeo_coder = RGeo::GeoJSON::Coder.new({:json_parser => :json})
      rgeo_feature = rgeo_coder.decode(geojson)
      id = rgeo_feature.properties["manure_zone_id"]
      attributes = rgeo_feature.properties["modalAttributes"]["group"]
      success = true

      zone= ManureManagementPlanZone.find(id)
      approach_applications = zone.manure_approach_applications
      approach_applications.each do |approach_app|
        approach = approach_app.approach
        unless approach.nil?
          response_questions = attributes[approach.supply_nature]
          approach_questions = approach.questions["questions"]
          approach_questions.values.each do |approach_question|
            label = approach_question["label"]
            approach_app.parameters[label] = response_questions[label]["value"]
          end
          success = false if not approach_app.save
        end
      end
      respond_to do |format|
        if success
          format.json  { render json: { :status => 'success'}}
        else
          format.json { render json: { status: 'errors' }, status: 500 }
        end
      end
    end

    def create_georeading
      file_saved = false

      geojson = params['shape']
      unless geojson.blank?
        rgeo_coder = RGeo::GeoJSON::Coder.new({:json_parser => :json})
        rgeo_feature = rgeo_coder.decode(geojson)

        id = rgeo_feature.properties["id"]
        georeading = nil
        errors = ""
        if id.nil?

          georeading = Georeading.new
          georeading.content = Charta.new_geometry(geojson)
          georeading.name = rgeo_feature.properties["name"]
          georeading.kind = rgeo_feature.properties["kind"] || ManureManagementPlan.manure_georeading_types.first
          georeading.nature = rgeo_feature.geometry.geometry_type.type_name.lower
          file_saved = georeading.save
          errors = georeading.errors.full_message unless file_saved
          id = georeading.id
        else
          file_saved = true
        end

        respond_to do |format|
          if file_saved
            format.json  { render json: { :id => id}}
          else
            format.json { render json: { error: errors }, status: 500 }
          end
        end
      end
    end

    def update_georeadings
      saved = true
      geojson = params['shape']
      unless geojson.blank?

        rgeo_coder = RGeo::GeoJSON::Coder.new({:json_parser => :json})
        rgeo_feature_collection = rgeo_coder.decode(geojson)
        rgeo_feature_collection.each do |rgeo_feature|
          id = rgeo_feature.properties["id"]
          next if id.nil?
          next if (georeading = Georeading.find_by_id(id)).nil?
          #case already exists

          georeading.content = rgeo_feature.geometry
          georeading.name = rgeo_feature.properties["name"] unless rgeo_feature.properties["name"].nil?
          georeading.kind = rgeo_feature.properties["kind"] unless rgeo_feature.properties["kind"].nil?
          georeading.nature = rgeo_feature.geometry.geometry_type.type_name.lower

          saved = georeading.save && saved
        end
      end
      respond_to do |format|
        if saved
          format.json  { render json: { :status => 'success'}}
        else
        end
      end
    end

    def delete_georeadings

      geojson = params['shape']
      success = false

      unless geojson.blank?
        rgeo_coder = RGeo::GeoJSON::Coder.new({:json_parser => :json})
        success = Georeading.delete(rgeo_coder.decode(geojson).properties["id"])
      end
      respond_to do |format|
        if success
          format.json  { render json: { status: :success}}
        else
          format.json { render json: { status: :error }, status: 500 }
        end
      end
    end
  end
end