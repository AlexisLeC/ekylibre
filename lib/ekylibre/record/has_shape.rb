module Ekylibre::Record
  module HasShape #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      SRID = {
        wgs84: 4326,
        rgf93: 2154
      }.freeze

      # Returns the corresponding SRID from its name or number
      def srid(srname)
        return srname if srname.is_a?(Integer)
        unless id = SRID[srname]
          fail ArgumentError.new("Unreferenced SRID: #{srname.inspect}")
        end
        id
      end

      def has_shape(*indicators)
        options = (indicators[-1].is_a?(Hash) ? indicators.delete_at(-1) : {})
        code = ''
        indicators = [:shape] if indicators.empty?
        column = :geometry_value

        for indicator in indicators
          # code << "after_create :create_#{indicator}_images\n"

          # code << "before_update :update_#{indicator}_images\n"

          code << "def self.#{indicator}_view_box(options = {})\n"
          code << "  expr = (options[:srid] ? \"ST_Transform(#{column}, \#{self.srid(options[:srid])})\" : '#{column}')\n"
          code << "  ids = ProductReading.of_products(self, :#{indicator}, options[:at]).pluck(:id)\n"
          code << "  return [] unless ids.any?\n"
          code << "  values = self.connection.select_one(\"SELECT min(ST_XMin(\#{expr})) AS x_min, min(ST_YMin(\#{expr})) AS y_min, max(ST_XMax(\#{expr})) AS x_max, max(ST_YMax(\#{expr})) AS y_max FROM \#{ProductReading.indicator_table_name(:#{indicator})} WHERE id IN (\#{ids.join(',')})\").symbolize_keys\n"
          code << "  return [values[:x_min].to_f, -values[:y_max].to_f, (values[:x_max].to_f - values[:x_min].to_f), (values[:y_max].to_f - values[:y_min].to_f)]\n"
          code << "end\n"

          # As SVG
          code << "def self.#{indicator}_svg(options = {})\n"
          # code << "  options[:srid] ||= 2154\n"
          code << "  ids = ProductReading.of_products(self, :#{indicator}, options[:at]).pluck(:product_id)\n"
          code << "  svg = '<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\"'\n"
          code << "  return (svg + '/>').html_safe unless ids.any?\n"
          code << "  svg << ' class=\"#{indicator}\" preserveAspectRatio=\"xMidYMid meet\" width=\"100%\" height=\"100%\" viewBox=\"' + #{indicator}_view_box(options).join(' ') + '\"'\n"
          code << "  svg << '>'\n"
          code << "  for product in Product.where(id: ids)\n"
          code << "    svg << '<path d=\"' + product.#{indicator}_to_svg_path(options) + '\"/>'\n"
          code << "  end\n"
          code << "  svg << '</svg>'\n"
          code << "  return svg.html_safe\n"
          code << "end\n"

          # Return SVG as String
          code << "def #{indicator}_svg(options = {})\n"
          code << "  options[:srid] ||= 2154\n"
          code << "  return nil unless reading = self.reading(:#{indicator}, at: options[:at])\n"
          code << "  geom = Charta::Geometry.new(self.#{indicator})\n"
          code << "  geom = geom.transform(options[:srid]) if options[:srid]\n"
          code << "  return geom.to_svg(options)\n"
          # code << "  options[:srid] ||= 2154\n"
          # code << "  return ('<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\""
          # for attr, value in {:class => indicator, :preserve_aspect_ratio => 'xMidYMid meet', :width => 180, :height => 180, :view_box => "self.#{indicator}_view_box(options).join(' ')".c}
          #   code << " #{attr.to_s.camelcase(:lower)}=\"' + (options[:#{attr}] || #{value.inspect}).to_s + '\""
          # end
          # code << "><path d=\"' + self.#{indicator}_to_svg(options).to_s + '\"/></svg>').html_safe\n"
          code << "end\n"

          # Return ViewBox
          code << "def #{indicator}_view_box(options = {})\n"
          code << "  return nil unless reading = self.reading(:#{indicator}, at: options[:at])\n"
          code << "  return [self.#{indicator}_x_min(options), -self.#{indicator}_y_max(options), self.#{indicator}_width(options), self.#{indicator}_height(options)]\n"
          code << "end\n"

          for attr in [:x_min, :x_max, :y_min, :y_max, :area, :to_svg, :to_svg_path, :to_gml, :to_kml, :to_geojson, :to_text, :to_binary, :to_ewkt, :centroid, :point_on_surface]
            code << "def #{indicator}_#{attr.to_s.downcase}(options = {})\n"
            code << "  return nil unless reading = self.reading(:#{indicator}, at: options[:at])\n"
            code << "  geometry = Charta::Geometry.new(reading.#{column})\n"
            code << "  geometry = geometry.transform(options[:srid]) if options[:srid]\n"
            code << "  return geometry.#{attr}\n"
            # code << "  expr = (options[:srid] ? \"ST_Transform(#{column}, \#{self.class.srid(options[:srid])})\" : '#{column}')\n"
            # code << "  value = self.class.connection.select_value(\"SELECT ST_#{attr.to_s.camelcase}(\#{expr}) FROM \#{ProductReading.indicator_table_name(:#{indicator})} WHERE id = \#{reading.id}\")\n"
            # if attr.to_s =~ /\Aas\_/
            #   code << "  return value.to_s"
            # else
            #   code << "  return (value.blank? ? 0.0 : value.to_d)"
            #   code << ".in_square_meter" if attr.to_s =~ /area\z/
            # end
            # code << "\n"
            code << "end\n"
          end

          # # add a method to convert polygon to point
          # # TODO : change geometry_value to a variable :column
          # for attr in [:centroid, :point_on_surface]
          #   code << "def #{indicator}_#{attr.to_s.downcase}(options = {})\n"
          #   code << "  return nil unless reading = self.reading(:#{indicator}, at: options[:at])\n"
          #   code << "  self.class.connection.select_value(\"SELECT ST_#{attr.to_s.camelcase}(geometry_value) FROM \#{ProductReading.indicator_table_name(:#{indicator})} WHERE id = \#{reading.id}\")\n"
          #   code << "end\n"
          # end

          code << "def #{indicator}_width(options = {})\n"
          code << "  return (self.#{indicator}_x_max(options) - self.#{indicator}_x_min(options))\n"
          code << "end\n"

          code << "def #{indicator}_height(options = {})\n"
          code << "  return (self.#{indicator}_y_max(options) - self.#{indicator}_y_min(options))\n"
          code << "end\n"

        end

        # code.split(/\n/).each_with_index{|l, i| puts (i+1).to_s.rjust(4) + ": " + l}

        class_eval code
      end
    end
  end
end
Ekylibre::Record::Base.send(:include, Ekylibre::Record::HasShape)
