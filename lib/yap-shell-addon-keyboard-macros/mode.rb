module YapShellAddonKeyboardMacros
  class Mode
    include ::RawLine::Editor::MajorMode

    def self.name
      :'keyboard-macros'
    end

    def self.on_read_bytes=(callback)
      @on_read_bytes_blk = callback
    end

    def self.on_read_bytes
      @on_read_bytes_blk
    end

    attr_reader :env, :previous_mode
    attr_accessor :bubble_input

    def initialize(previous: nil, bubble_input: true)
      @previous_mode = previous
      @bubble_input = bubble_input
    end

    def bubble_input?
      !!@bubble_input
    end

    def activate(editor)
      @editor = editor
    end

    def deactivate(editor)
    end

    def read_bytes(bytes)
      self.class.on_read_bytes.call(bytes)
    end
  end
end
