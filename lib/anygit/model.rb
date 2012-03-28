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
      DataMapper::Logger.new($stdout, :debug)

      # A MySQL connection:
      DataMapper.setup(:default, 'mysql://root@localhost/anygit')

      DataMapper.finalize
    end

    class Repo
      include DataMapper::Resource

      property :id, Serial
      property :url, String, :length => 3000
      property :created_at, DateTime
      property :fetched_at, DateTime
    end

    # # Repo mappings

    class BlobRepo
      include DataMapper::Resource

      # Requires my patches to dm-core / dm-migrations
      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    class TreeRepo
      include DataMapper::Resource

      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    class CommitRepo
      include DataMapper::Resource

      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    class TagRepo
      include DataMapper::Resource

      property :sha1, String, SHA1_KEY_OPTS
      belongs_to :repo, :key => true
      property :created_at, DateTime
    end

    # # Pointers

    # ## Blobs

    class BlobTree
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    class BlobTag
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    ## Tree

    class TreeTree
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    class TreeCommit
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    class TreeTag
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    ## Commit

    class CommitCommit
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    class CommitTag
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end

    ## Tag

    class TagTag
      include DataMapper::Resource

      property :source, String, SHA1_KEY_OPTS
      property :target, String, SHA1_KEY_OPTS
      property :created_at, DateTime
    end
  end
end
