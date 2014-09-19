module Exchanges

  class Jauge

    def initialize(&block)
      if block_given?
        unless (1..2).include?(block.arity)
          raise "Invalid arity must be 1..2"
        end
        @block = block
      end
      @max = ENV["max"].to_i
      @count = nil
      @cursor = 0
    end

    def count=(value)
      raise "Need a positive value" unless value > 0
      @count = value
      @count = @max if @max > 0 and @count > @max
    end

    def check_point(new_cursor = nil)
      unless @count
        raise "You need to set count before calling check_point"
      end
      if new_cursor
        @cursor = new_cursor
      else
        @cursor += 1
      end
      if @block
        value = (100.0*(@cursor.to_f / @count.to_f)).to_i
        if value != @last_value
          if @block.arity == 1
            @block.call(value)
          elsif @block.arity == 2
            @block.call(value, @cursor)
          end
          @last_value = value
        end
      end
    end

    def reset!
      @cursor = 0
    end

  end

end
