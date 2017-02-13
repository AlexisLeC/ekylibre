module Procedo
  class Procedure
    # An Attribute defines an information to complete
    class Attribute < Procedo::Procedure::Setter

      TYPES = [:new_name, :working_zone, :variety, :derivative_of, :new_container, :new_group, :killable, :new_variant, :variant].freeze

      def initialize(parameter, name, options = {})
        super(parameter, name, options)
        unless TYPES.include?(@name)
          raise "Unknown attribute type for #{procedure_name}/#{parameter_name}: " + @name.inspect
        end
      end
    end
  end
end
