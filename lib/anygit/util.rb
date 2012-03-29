require 'mysql'

module Anygit
  module Util
    def self.sha1_to_bytes(sha1)
      [sha1].pack("H*")
    end

    def self.sha1_to_hex(sha1)
      sha1.unpack("H*")[0]
    end

    # HACK: should shell out to an actual mysql library for all of
    # these...
    def self.validate_table_name(name)
      if name.include?('`') || name.include?('?')
        raise "Table names can't contain backticks or question marks: #{name.inspect}"
      end
      name
    end

    def self.sql_column_name_quote(str)
      str = str.to_s
      raise "Invalid column name" if str.include?(',') || str.include?(')')
      str
    end

    def self.sql_value_quote(str)
      "'" + sql_escape(str) + "'"
    end

    private

    def self.sql_escape(str)
      # str.to_s.gsub(/\\|'/) { |c| "\\#{c}" }.gsub("\0", '\0')
      Mysql.escape_string(str.to_s)
    end
  end
end
