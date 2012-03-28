require 'pathname'
require 'sinatra/base'
require 'rack/utils'

module Anygit
  class WebInterface < Sinatra::Base
    set :root, Pathname.new(File.join(File.dirname(__FILE__), '../..')).realpath

    get '/q/:sha1' do
      @limit = 10
      @sha1 = sha1 = params[:sha1]

      if sha1.length > 40
        halt 400, "SHA1s must be no more than 40 characters"
      elsif sha1 !~ /^[a-f0-9]+$/
        halt 400, "SHA1s must be in hex"
      end

      binary_sha1 = Util.sha1_to_bytes(sha1)
      if upper = upper_bound(binary_sha1)
        Anygit.log.info("Querying for objects bounded between [#{binary_sha1.inspect}, #{upper.inspect})")
        @collection = Model::GitObject.all(:sha1.gte => binary_sha1, :sha1.lt => upper, :limit => @limit)
      else
        Anygit.log.info("Querying for objects bounded below by #{binary_sha1.inspect}")
        @collection = Model::GitObject.all(:sha1.gte => binary_sha1, :limit => @limit)
      end

      if @collection.count == 1
        object = @collection.first

        op_name = Util.validate_table_name(Anygit::Model::ObjectPointer.storage_name)
        go_name = Util.validate_table_name(Anygit::Model::GitObject.storage_name)
        puts "ZOMBIE!"
        # TODO: paginate, filter by type
        @raw_pointers = repository(:default).adapter.select("
SELECT b.sha1, b.type
FROM #{op_name} AS a LEFT JOIN #{go_name} AS b
ON a.source = b.sha1
WHERE a.target = ?
LIMIT ?
", object.sha1, @limit)
        @git_objects = @raw_pointers.map do |pointer|
          puts "ZOOM ZOOH ZOOM!"
          go = Model::GitObject.new
          go.sha1 = pointer.sha1
          go.type = pointer.type
          go
        end
        erb :q_one
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
