module Enumerize
  class Value
    def localize
      text
    end
    alias l localize

    def to_xml(options = {})
      require 'active_support/builder' unless defined?(Builder)

      options = options.dup
      options[:indent] ||= 2
      options[:root] ||= 'hash'
      options[:builder] ||= Builder::XmlMarkup.new(indent: options[:indent])

      builder = options[:builder]
      builder.instruct! unless options.delete(:skip_instruct)

      root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)

      builder.__send__(:method_missing, root, name: to_s) do
        text.to_s
      end
    end
  end

  class Attribute
    def human_value_name(value)
      Value.new(self, value).l
    end
  end
end
