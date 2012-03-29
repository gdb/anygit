require 'data_mapper'
require 'cgi'

module Anygit
  module Model
    SHA1_KEY_OPTS = {
      :length => 20,
      :key => true,
      :adapter_opts => {
        :primitive => 'CHAR',
        :character_set => 'BINARY'
      }
    }

    def self.init
      # If you want the logs displayed you have to do this before the call to setup
      # DataMapper::Logger.new($stdout, :debug)

      # A MySQL connection:
      DataMapper.setup(:default, 'mysql://root@localhost/anygit')

      DataMapper.finalize
    end

    class Repo
      include DataMapper::Resource

      property :id, Serial
      # TODO: support aliasing
      property :url, String, :length => 3000
      property :template, String, :length => 3000
      property :created_at, DateTime
      property :fetched_at, DateTime

      # Really should store the template
      def webview(type, hex_sha1)
        return template.gsub('{sha1}', hex_sha1) if template

        parsed = URI.parse(url)
        if parsed.host == 'github.com'
          parsed
          parsed.scheme = 'https'
          parsed.path = $1 if parsed.path =~ /^(.*)(\.git|\/)$/
          parsed.path += "/#{CGI.escape(type)}/#{CGI.escape(hex_sha1)}"
        else
          raise "Not sure how to build a template for #{self}: #{parsed}"
        end
        parsed.to_s
      end
    end

    class GitObject
      include DataMapper::Resource

      property :sha1, String, SHA1_KEY_OPTS
      property :type, String
      property :created_at, DateTime

      def hex_sha1
        Util.sha1_to_hex(sha1)
      end
    end

    class ObjectRepo
      include DataMapper::Resource

      # Requires my patches to dm-core / dm-migrations
      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    # class ObjectPointer
    #   include DataMapper::Resource

    #   # Requires my patches to dm-core / dm-migrations.
    #   #
    #   # Note that index isn't autocreating itself at the moment (might
    #   # want to reverse order?) so run
    #   # CREATE INDEX target ON anygit_model_object_pointers (target ASC)
    #   property :source, String, SHA1_KEY_OPTS
    #   property :target, String, SHA1_KEY_OPTS.merge(:index => true)
    #   property :created_at, DateTime
    # end
  end
end
