module YapShellAddonKeyboardMacros
  module PrettyPrintKey
    # ppk means "pretty print key". For example, it returns \C-g if the given
    # byte is 7.
    def ppk(byte)
      if byte && byte.ord <= 26
        '\C-' + ('a'..'z').to_a[byte.ord - 1]
      else
        byte.inspect
      end
    end
  end
end
