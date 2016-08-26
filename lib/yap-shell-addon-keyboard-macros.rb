require 'yap/addon'
require 'yap-shell-addon-keyboard-macros/version'
require 'yap-shell-addon-keyboard-macros/mode'
require 'yap-shell-addon-keyboard-macros/cancellation'
require 'yap-shell-addon-keyboard-macros/configuration'
require 'yap-shell-addon-keyboard-macros/definition'
require 'yap-shell-addon-keyboard-macros/cycle'
require 'yap-shell-addon-keyboard-macros/pretty_print_key'

module YapShellAddonKeyboardMacros
  class Addon < ::Yap::Addon::Base
    self.export_as :'keyboard-macros'

    include PrettyPrintKey

    DEFAULT_TRIGGER_KEY = :ctrl_g
    DEFAULT_CANCEL_KEY = " "
    DEFAULT_TIMEOUT_IN_MS = 500

    attr_reader :world
    attr_accessor :timeout_in_ms
    attr_accessor :cancel_key, :trigger_key
    attr_accessor :cancel_on_unknown_sequences

    def initialize_world(world)
      @world = world
      @world.editor.register_mode Mode

      @configurations = []
      @stack = []
      @timeout_in_ms = DEFAULT_TIMEOUT_IN_MS
      @cancel_key = DEFAULT_CANCEL_KEY
      @trigger_key = DEFAULT_TRIGGER_KEY
      @cancel_on_unknown_sequences = false
    end

    def mode
      Mode
    end

    def cancel_key=(key)
      logger.puts "setting default cancel_key key=#{ppk(key)}"
      @cancel_key = key
    end

    def cancel_on_unknown_sequences=(true_or_false)
      logger.puts "setting default cancel_on_unknown_sequences=#{true_or_false}"
      @cancel_on_unknown_sequences = true_or_false
    end

    def timeout_in_ms=(milliseconds)
      logger.puts "setting default timeout_in_ms milliseconds=#{milliseconds.inspect}"
      @timeout_in_ms = milliseconds
    end

    def trigger_key=(key)
      logger.puts "setting default trigger_key key=#{ppk(key)}"
      @trigger_key = key
    end

    def configure(cancel_key: nil, trigger_key: nil, &blk)
      logger.puts "configure cancel_key=#{ppk(cancel_key)} trigger_key=#{ppk(trigger_key)} block_given?=#{block_given?}"

      cancel_key ||= @cancel_key
      trigger_key ||= @trigger_key

      cancel_blk = lambda do
        world.editor.event_loop.clear @event_id
        cancel_processing
        nil
      end

      configuration = Configuration.new(
        keymap: world.editor.terminal.keys,
        trigger_key: trigger_key,
        cancellation: Cancellation.new(cancel_key: cancel_key, &cancel_blk),
        editor: world.editor,
      )

      blk.call configuration if blk

      world.unbind(trigger_key)
      world.bind(trigger_key) do
        logger.puts "macro triggered key=#{ppk(trigger_key)}"
        world.editor.activate_mode Mode.name

        begin
          @previous_result = nil
          @stack << OpenStruct.new(configuration: configuration)
          configuration.start.call if configuration.start
          wait_timeout_in_seconds = 0.1
          world.editor.input.wait_timeout_in_seconds = wait_timeout_in_seconds
          Mode.on_read_bytes = -> (bytes) { on_mode_read_bytes(bytes) }
        ensure
          queue_up_remove_input_processor(&configuration.stop)
        end
      end

      @configurations << configuration
    end

    def cycle(name, &cycle_thru_blk)
      logger.puts "defining cycle name=#{name.inspect}"

      @cycles ||= {}
      if block_given?
        cycle = YapShellAddonKeyboardMacros::Cycle.new(
          cycle_proc: cycle_thru_blk,
          on_cycle_proc: -> (old_value, new_value) {
            @world.editor.delete_n_characters(old_value.to_s.length)
            process_result(new_value)
          }
        )
        @cycles[name] = cycle
      else
        @cycles.fetch(name)
      end
    end

    private

    def on_mode_read_bytes(bytes)
      if @stack.last
        current_definition = @stack.last
        configuration = current_definition.configuration
      end

      bytes.each_with_index do |byte, i|
        definition = configuration[byte]
        if !definition
          cancel_processing if cancel_on_unknown_sequences
          return bytes[i..-1] # short-circuit out, left over bytes
        end

        configuration = definition.configuration
        configuration.start.call if configuration.start
        @stack << definition

        result = definition.process

        if result =~ /\n$/
          world.editor.write result.chomp, add_to_line_history: false
          world.editor.event_loop.clear @event_id if @event_id
          cancel_processing
          world.editor.newline # add_to_history
          world.editor.process_line
          break
        end

        if i == bytes.length - 1
          while @stack.last && @stack.last.fragment?
            @stack.pop
          end
        end

        if @event_id
          world.editor.event_loop.clear @event_id
          @event_id = queue_up_remove_input_processor
        end

        process_result(result)
      end

      []
    end

    def process_result(result)
      if result.is_a?(String)
        @world.editor.write result, add_to_line_history: false
        @previous_result = result
      end
    end

    def queue_up_remove_input_processor(&blk)
      return unless @timeout_in_ms

      event_args = {
        name: 'remove_input_processor',
        source: self,
        interval_in_ms: @timeout_in_ms,
      }
      @event_id = world.editor.event_loop.once(event_args) do
        cancel_processing
      end
    end

    def cancel_processing
      logger.puts "cancel_processing"
      @event_id = nil
      @stack.reverse.each do |definition|
        definition.configuration.stop.call if definition.configuration.stop
      end
      @stack.clear

      logger.puts "restoring default editor input timeout"
      world.editor.input.restore_default_timeout

      world.editor.deactivate_mode Mode.name
    end
  end
end
