module YapShellAddonKeyboardMacros
  class Definition
    attr_reader :configuration, :result, :sequence

    def initialize(configuration: nil, fragment: false, sequence:, result: nil)
      @fragment = fragment
      @configuration = configuration
      @sequence = sequence
      @result = result
    end

    def inspect
      "<Definition fragment=#{@fragment.inspect} sequence=#{@sequence.inspect} result=#{@result.inspect} configuration=#{@configuration.inspect}>"
    end

    def fragment?
      @fragment
    end

    def matches?(byte)
      if @sequence.is_a?(Regexp)
        @match_data = @sequence.match(byte.chr)
      else
        @sequence == byte
      end
    end

    def process
      if @result
        if @match_data
          if @match_data.captures.empty?
            @result.call(@match_data[0])
          else
            @result.call(*@match_data.captures)
          end
        else
          @result.call
        end
      end
    end
  end
end
