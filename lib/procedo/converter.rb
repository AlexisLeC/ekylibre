module Procedo
  module HandlerMethod
    class Base < Treetop::Runtime::SyntaxNode; end
    class Expression < Base; end
    class Condition < Base; end
    class Operation < Base; end # Abstract
    class Multiplication < Operation; end
    class Division < Operation; end
    class Addition < Operation; end
    class Substraction < Operation; end
    class BooleanExpression < Base; end
    class BooleanOperation < Base; end
    class Conjunction < BooleanOperation; end
    class Disjunction < BooleanOperation; end
    class ExclusiveDisjunction < BooleanOperation; end
    class Test < Base; end # Abstract
    class Comparison < Test; end # Abstract
    class StrictSuperiorityComparison < Comparison; end
    class StrictInferiortyComparison < Comparison; end
    class SuperiorityComparison < Comparison; end
    class InferiorityComparison < Comparison; end
    class EqualityComparison < Comparison; end
    class DifferenceComparison < Comparison; end
    class IndicatorPresenceTest < Test; end
    class ActorPresenceTest < Test; end
    class NegativeTest < Test; end
    class Access < Base; end
    class Reading < Base; end # Abstract
    class IndividualReading < Reading; end
    class WholeReading < Reading; end
    class FunctionCall < Base; end
    class FunctionName < Base; end
    class OtherArgument < Base; end
    class Variable < Base; end
    class Accessor < Base; end
    class Indicator < Base; end
    class Unit < Base; end
    class Self < Base; end
    class Value < Base; end
    class Numeric < Base; end

    class << self
      def parse(text, options = {})
        @@parser ||= ::Procedo::HandlerMethodParser.new
        unless tree = @@parser.parse(text.to_s, options)
          fail SyntaxError, @@parser.failure_reason
        end
        tree
      end

      # def clean_tree(root)
      #   return if root.elements.nil?
      #   root.elements.delete_if{ |node| node.class.name == "Treetop::Runtime::SyntaxNode" }
      #   root.elements.each{ |node| clean_tree(node) }
      # end
    end
  end

  class Converter
    @@whole_indicators = Nomen::Indicator.where(related_to: :whole).collect { |i| i.name.to_sym }
    cattr_reader :whole_indicators

    attr_reader :destination, :backward_tree, :forward_tree, :handler, :attributes

    class << self
      def count_variables(node, name)
        if (node.is_a?(Procedo::HandlerMethod::Self) && name == :self) ||
           (node.is_a?(Procedo::HandlerMethod::Variable) && name.to_s == node.text_value)
          return 1
        end
        return 0 unless node.elements
        node.elements.inject(0) do |count, child|
          count += count_variables(child, name)
          count
        end
      end
    end

    def initialize(handler, element = nil)
      @handler = handler
      # Extract attributes from XML element
      @attributes = if element.is_a?(Hash)
                      element
                    else
                      %w(to forward backward).inject({}) do |hash, attr|
                        hash[attr.to_sym] = element.attr(attr) if element.has_attribute?(attr)
                        hash
                      end
                    end

      @destination = (@attributes[:to] || @handler.indicator.name).to_sym
      unless @@whole_indicators.include?(@destination)
        fail Procedo::Errors::InvalidHandler, "Handler must have a valid destination (#{@@whole_indicators.to_sentence} expected, got #{@destination})"
      end

      if @attributes[:forward]
        begin
          @forward_tree = HandlerMethod.parse(@attributes[:forward].to_s)
        rescue SyntaxError => e
          raise SyntaxError, "A procedure handler (#{@attributes.inspect}) #{handler.procedure.name} has a syntax error on forward formula: #{e.message}"
        end
      end

      if @attributes[:backward]
        begin
          @backward_tree = HandlerMethod.parse(@attributes[:backward].to_s)
        rescue SyntaxError => e
          raise SyntaxError, "A procedure handler (#{@attributes.inspect}) #{handler.procedure.name} has a syntax error on backward formula: #{e.message}"
        end
      end
    end

    def forward?
      @forward_tree.present?
    end

    def backward?
      @backward_tree.present?
    end

    # Variable
    def variable
      @handler.variable
    end

    # Procedure
    def procedure
      @handler.procedure
    end

    # Returns keys
    def depend_on?(variable_name, mode = nil)
      count = 0
      if forward? && (mode.nil? || mode == :forward)
        count += self.class.count_variables(@forward_tree, variable_name)
      end
      if backward? && (mode.nil? || mode == :backward)
        count += self.class.count_variables(@backward_tree, variable_name)
      end
      !count.zero?
    end
  end
end
