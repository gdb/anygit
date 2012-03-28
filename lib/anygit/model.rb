require 'data_mapper'

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
      property :created_at, DateTime
      property :fetched_at, DateTime
    end

    class GitObject
      include DataMapper::Resource

      property :sha1, String, SHA1_KEY_OPTS
      property :type, Enum[:commit, :type, :tag, :blob]
      property :created_at, DateTime
    end

    class ObjectRepo
      include DataMapper::Resource

      # Requires my patches to dm-core / dm-migrations
      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    class ObjectPointer
      include DataMapper::Resource

      # Requires my patches to dm-core / dm-migrations
      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end
  end
end
