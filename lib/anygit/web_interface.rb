require 'pathname'
require 'sinatra/base'
require 'rack/utils'

module Anygit
  class WebInterface < Sinatra::Base
    LIMIT = 10
    set :root, Pathname.new(File.join(File.dirname(__FILE__), '../..')).realpath

    get '/' do
      index
    end

    post '/repos' do
      query = {:url => params[:url]}

      if r = Model::Repo.first(query)
        if r.index_state == 'pending'
          @flash = "Repo at #{r.url} is already marked for indexing; have no fear--we will get to it."
        elsif r.index_state == 'indexed'
          @flash = "Marking repo at #{r.url} for reindexing"
        elsif r.index_state == 'failed'
          @flash = "Last attempt to index repo at #{r.url} failed, but I'll try again."
        else
          raise "Invalid indexing state: #{r.index_state} for #{r}"
        end
      else
        r = Model::Repo.create(query)
        @flash = "Adding repo at #{r.url} to the index"
      end

      r.index_state = 'pending'
      r.save

      # Too lazy to actually add the flash
      index
    end

    def index
      # Could do more efficiently via group_by I think.
      @repo_count = Model::Repo.count(:been_indexed => 'true')
      @commit_count = Model::GitObject.count(:type => 'commit')
      @tree_count = Model::GitObject.count(:type => 'tree')
      @blob_count = Model::GitObject.count(:type => 'blob')
      @tag_count = Model::GitObject.count(:type => 'tag')

      @largest_repos = Model::ObjectRepo.most_popular(5)
      erb :index
    end

    get '/about' do
      erb :about
    end

    get '/q/?:sha1?' do
      @limit = LIMIT
      @sha1 = sha1 = params[:sha1] || ''

      if sha1.length > 40
        halt 400, "SHA1s must be no more than 40 characters"
      elsif sha1 !~ /^[a-f0-9]*$/
        halt 400, "SHA1s must be in hex"
      end

      if sha1 == ''
        Anygit.log.info("Querying for all objects")
        @collection = Model::GitObject.all(:limit => @limit)
      else
        binary_sha1 = Util.sha1_to_bytes(sha1)
        if upper = upper_bound(binary_sha1)
          Anygit.log.info("Querying for objects bounded between [#{binary_sha1.inspect}, #{upper.inspect})")
          @collection = Model::GitObject.all(:sha1.gte => binary_sha1, :sha1.lt => upper, :limit => @limit)
        else
          Anygit.log.info("Querying for objects bounded below by #{binary_sha1.inspect}")
          @collection = Model::GitObject.all(:sha1.gte => binary_sha1, :limit => @limit)
        end
      end

      if @collection.count == 1
        # Should start using joins
        object = @collection.first
        unless object_repo = Model::ObjectRepo.first(:sha1 => object.sha1)
          raise "Data corruption: objectrepo found"
        end
        repo = object_repo.repo
        dest = repo.webview(object.type, object.hex_sha1)
        Anygit.log.info("Redirecting to #{dest}")
        redirect(dest)
      else
        erb :q_many
      end
    end

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    def upper_bound(prefix)
      if prefix.length == 0
        nil
      elsif prefix[-1] == 255
        upper_bound(prefix[0...-1])
      else
        prefix[0...-1] + (prefix[-1] + 1).chr
      end
    end
  end
end
