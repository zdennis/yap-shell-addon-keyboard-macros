require 'yap-shell-addon-keyboard-macros/pretty_print_key'

module YapShellAddonKeyboardMacros
  class Configuration
    include PrettyPrintKey

    attr_reader :cancellation, :trigger_key, :keymap

    def logger
      Addon.logger
    end

    def initialize(cancellation: nil, editor:, keymap: {}, trigger_key: nil)
      @cancellation = cancellation
      @editor = editor
      @keymap = keymap
      @trigger_key = trigger_key
      @storage = {}
      @on_start_blk = nil
      @on_stop_blk = nil
      @cycles = {}

      logger.puts "configuring a macro trigger_key=#{ppk(trigger_key)}"

      if @cancellation
        define @cancellation.cancel_key, -> { @cancellation.call }
      end
    end

    def start(&blk)
      @on_start_blk = blk if blk
      @on_start_blk
    end

    def stop(&blk)
      @on_stop_blk = blk if blk
      @on_stop_blk
    end

    def cycle(name, &cycle_thru_blk)
      logger.puts "defining a cycle on macro name=#{name.inspect}"

      if block_given?
        cycle = YapShellAddonKeyboardMacros::Cycle.new(
          cycle_proc: cycle_thru_blk,
          on_cycle_proc: -> (old_value, new_value) {
            @editor.delete_n_characters(old_value.to_s.length)
          }
        )
        @cycles[name] = cycle
      else
        @cycles.fetch(name)
      end
    end

    def fragment(sequence, result)
      define(sequence, result, fragment: true)
    end

    def define(sequence, result=nil, fragment: false, &blk)
      logger.puts "defining macro sequence=#{sequence.inspect} result=#{result.inspect} fragment=#{fragment.inspect} under macro #{ppk(trigger_key)}"
      unless result.respond_to?(:call)
        string_result = result
        result = -> { string_result }
      end

      case sequence
      when String
        recursively_define_sequence_for_bytes(
          self,
          sequence.bytes,
          result,
          fragment: fragment,
          &blk
        )
      when Symbol
        recursively_define_sequence_for_bytes(
          self,
          @keymap.fetch(sequence){
            fail "Cannot bind unknown sequence #{sequence.inspect}"
          },
          result,
          fragment: fragment,
          &blk
        )
      when Regexp
        define_sequence_for_regex(sequence, result, fragment: fragment, &blk)
      else
        raise NotImplementedError, <<-EOT.gsub(/^\s*/, '')
          Don't know how to define macro for sequence: #{sequence.inspect}
        EOT
      end
    end

    def [](byte)
      @storage.values.detect { |definition| definition.matches?(byte) }
    end

    def []=(key, definition)
      @storage[key] = definition
    end

    def inspect
      str = @storage.map{ |k,v| "#{k}=#{v.inspect}" }.join("\n  ")
      num_items = @storage.reduce(0) { |s, arr| s + arr.length }
      "<Configuration num_items=#{num_items} stored_keys=#{str}>"
    end

    private

    def define_sequence_for_regex(regex, result, fragment: false, &blk)
      @storage[regex] = Definition.new(
        configuration: Configuration.new(
          cancellation: @cancellation,
          keymap: @keymap,
          editor: @editor
        ),
        fragment: fragment,
        sequence: regex,
        result: result,
        &blk
      )
    end

    def recursively_define_sequence_for_bytes(configuration, bytes, result, fragment: false, &blk)
      byte, rest = bytes[0], bytes[1..-1]
      if rest.any?
        definition = if configuration[byte]
          configuration[byte]
        else
          Definition.new(
            configuration: Configuration.new(
              cancellation: @cancellation,
              keymap: @keymap,
              editor: @editor
            ),
            fragment: fragment,
            sequence: byte,
            result: nil
          )
        end
        blk.call(definition.configuration) if blk
        configuration[byte] = definition
        recursively_define_sequence_for_bytes(
          definition.configuration,
          rest,
          result,
          fragment: fragment,
          &blk
        )
      else
        definition = Definition.new(
          configuration: Configuration.new(
            keymap: @keymap,
            editor: @editor
          ),
          fragment: fragment,
          sequence: byte,
          result: result
        )
        configuration[byte] = definition
        blk.call(definition.configuration) if blk
        definition
      end
    end
  end
end
