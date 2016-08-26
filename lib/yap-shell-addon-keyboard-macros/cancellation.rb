module YapShellAddonKeyboardMacros
  class Cancellation
    attr_reader :cancel_key

    def initialize(cancel_key: , &blk)
      @cancel_key = cancel_key
      @blk = blk
    end

    def call
      @blk.call
    end
  end
end
