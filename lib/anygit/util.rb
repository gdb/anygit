module Anygit
  module Util
    def self.sha1_to_bytes(sha1)
      [sha1].pack("H*")
    end

    def self.sha1_to_hex(sha1)
      sha1.unpack("H*")[0]
    end
  end
end
