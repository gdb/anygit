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
      property :index_state, String, :default => 'unstarted'
      # Should really just be a bool
      property :been_indexed, String, :index => true, :default => 'false'
      property :created_at, DateTime
      property :fetched_at, DateTime

      # Really should store the template
      def webview(type, hex_sha1)
        raise "#{type.inspect} view not yet supported" if type == 'tree' || type == 'blob'
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
      property :type, String, :index => true
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

      def self.most_popular(limit)
        or_name = Util.validate_table_name(ObjectRepo.storage_name)
        r_name = Util.validate_table_name(Repo.storage_name)
        repository(:default).adapter.select("SELECT b.url, a.repo_id, COUNT(*) as count FROM #{or_name} AS a JOIN #{r_name} AS b ON a.repo_id = b.id GROUP BY repo_id ORDER BY count DESC LIMIT ?", limit)
      end
    end
  end
end
