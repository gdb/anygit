module Anygit
  module Util
    def self.sha1_to_bytes(sha1)
      [sha1].pack("H*")
    end

    def self.sha1_to_hex(sha1)
      sha1.unpack("H*")[0]
    end

    def self.validate_table_name(name)
      if name.include?('`') || name.include?('?')
        raise "Table names can't contain backticks or question marks: #{name.inspect}"
      end
      name
    end
  end
end
