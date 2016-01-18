module Ekylibre::Record
  class Scope < Struct.new(:name, :arity)
  end

  class Base < ActiveRecord::Base
    self.abstract_class = true

    cattr_accessor :scopes do
      []
    end

    # Replaces old module: ActiveRecord::Acts::Tree
    # include ActsAsTree

    # Permits to use enumerize in all models
    extend Enumerize

    # Make all models stampables
    stampable

    before_update :check_if_updateable?
    before_destroy :check_if_destroyable?

    def check_if_updateable?
      true
      # raise RecordNotUpdateable unless self.updateable?
    end

    def check_if_destroyable?
      unless destroyable?
        fail RecordNotDestroyable, "#{self.class.name} ID=#{id} is not destroyable"
      end
    end

    def destroyable?
      true
    end

    def updateable?
      true
    end

    def editable?
      updateable?
    end

    def human_attribute_name(*args)
      self.class.human_attribute_name(*args)
    end

    # Returns a relation for all other records
    def others
      self.class.where.not(id: (id || -1))
    end

    # Returns a relation for the old record in DB
    def old_record
      return nil if new_record?
      self.class.find_by(id: id)
    end

    # Returns the definition of custom fields of the object
    def custom_fields
      self.class.custom_fields
    end

    # Returns the value of given custom_field
    def custom_value(field)
      self[field.column_name]
    end

    def already_updated?
      self.class.where(id: id, lock_version: lock_version).empty?
    end

    validate :validate_custom_fields

    def validate_custom_fields
      for custom_field in custom_fields
        value = custom_value(custom_field)
        if value.blank?
          errors.add(custom_field.column_name, :blank, attribute: custom_field.name) if custom_field.required?
        else
          if custom_field.text?
            unless custom_field.maximal_length.blank? || custom_field.maximal_length <= 0
              errors.add(custom_field.column_name, :too_long, attribute: custom_field.name, count: custom_field.maximal_length) if value.length > custom_field.maximal_length
            end
            unless custom_field.minimal_length.blank? || custom_field.minimal_length <= 0
              errors.add(custom_field.column_name, :too_short, attribute: custom_field.name, count: custom_field.maximal_length) if value.length < custom_field.minimal_length
            end
          elsif custom_field.decimal?
            value = value.to_d unless value.is_a?(Numeric)
            unless custom_field.minimal_value.blank?
              errors.add(custom_field.column_name, :greater_than, attribute: custom_field.name, count: custom_field.minimal_value) if value < custom_field.minimal_value
            end
            unless custom_field.maximal_value.blank?
              errors.add(custom_field.column_name, :less_than, attribute: custom_field.name, count: custom_field.maximal_value) if value > custom_field.maximal_value
            end
          end
        end
      end
    end

    def method_missing(method_name, *args)
      if method_name.to_s.start_with?('_')
        unless self.class.columns.detect { |c| c.name == method_name.to_s }
          Rails.logger.warn 'Reset column information'
          self.class.reset_column_information
        end
      end
      super
    end

    @@readonly_counter = 0

    class << self
      def reset_schema
        # self.reset_column_information
        # self.descendants.each(&:reset_column_information)
        connection.clear_cache!
        base_class.reset_column_information
        base_class.descendants.each(&:reset_column_information)
      end

      def has_picture
        has_attached_file :picture,           url: '/backend/:class/:id/picture/:style',
                                              path: ':tenant/:class/:attachment/:id_partition/:style.:extension',
                                              styles: {
                                                thumb: ['64x64>', :jpg],
                                                identity: ['180x180>', :jpg]
                                              },
                                              convert_options: {
                                                thumb:    '-background white -gravity center -extent 64x64',
                                                identity: '-background white -gravity center -extent 180x180'
                                              }
      end

      # Returns the definition of custom fields of the class
      def custom_fields
        CustomField.of(name)
      end

      def columns_definition
        Ekylibre::Schema.tables[table_name] || {}.with_indifferent_access
      end

      def simple_scopes
        scopes.select { |x| x.arity.zero? }
      end

      def complex_scopes
        scopes.select { |x| !x.arity.zero? }
      end

      # Permits to consider something and something_id like the same
      def scope_with_registration(name, body, &block)
        # Check body.is_a?(Relation) to prevent the relation actually being
        # loaded by respond_to?
        if body.is_a?(::ActiveRecord::Relation) || !body.respond_to?(:call)
          ActiveSupport::Deprecation.warn('Using #scope without passing a callable object is deprecated. For ' \
                                          "example `scope :red, where(color: 'red')` should be changed to " \
                                          "`scope :red, -> { where(color: 'red') }`. There are numerous gotchas " \
                                          'in the former usage and it makes the implementation more complicated ' \
                                          'and buggy. (If you prefer, you can just define a class method named ' \
                                          "`self.red`.)\n" + caller.join("\n")
                                         )
        end
        arity = begin
                  body.arity
                rescue
                  0
                end
        scopes << Scope.new(name.to_sym, arity)
        scope_without_registration(name, body, &block)
      end
      alias_method_chain :scope, :registration

      def nomenclature_reflections
        @nomenclature_reflections ||= {}.with_indifferent_access
      end

      # Link to nomenclature
      def refers_to(name, options = {})
        reflection = Nomen::Reflection.new(self, name, options)
        @nomenclature_reflections ||= {}.with_indifferent_access
        @nomenclature_reflections[reflection.name] = reflection
        enumerize reflection.name, in: reflection.klass.all(reflection.scope), i18n_scope: ["nomenclatures.#{reflection.nomenclature}.items"]
      end

      # Permits to consider something and something_id like the same
      def human_attribute_name_with_id(attribute, options = {})
        human_attribute_name_without_id(attribute.to_s.gsub(/_id\z/, ''), options)
      end
      alias_method_chain :human_attribute_name, :id

      def has_human_attribute_name?(name)
        # TODO: don't use hardtranslate
        I18n.hardtranslate("attributes.#{name}").present?
      end

      # Permits to add conditions on attr_readonly
      def attr_readonly_with_conditions(*args)
        options = args.extract_options!
        return attr_readonly_without_conditions(*args) unless options[:if]
        if options[:if].is_a?(Symbol)
          method_name = options[:if]
        else
          method_name = "readonly_#{@@readonly_counter += 1}?"
          send(:define_method, method_name, options[:if])
        end
        code = ''
        code << "before_update do\n"
        code << "  if self.#{method_name}\n"
        code << "    old = #{name}.find(self.id)\n"
        for attribute in args
          code << "  self['#{attribute}'] = old['#{attribute}']\n"
        end
        code << "  end\n"
        code << "end\n"
        class_eval code
      end
      alias_method_chain :attr_readonly, :conditions
    end
  end
end
