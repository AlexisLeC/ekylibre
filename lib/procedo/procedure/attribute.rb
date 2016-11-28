module Procedo
  class Procedure
    # An Attribute defines an information to complete
    class Attribute < Procedo::Procedure::Setter
      # TODO: change types with ids as it's a rails paradigm
      TYPES = [:new_name, :working_zone, :variety, :derivative_of, :new_container_id, :new_group_id, :new_variant, :variant].freeze

      def initialize(parameter, name, options = {})
        super(parameter, name, options)
        unless TYPES.include?(@name)
          raise "Unknown attribute type for #{procedure_name}/#{parameter_name}: " + @name.inspect
        end
      end
    end
  end
end
