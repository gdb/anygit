module Anygit::Indexer
  TMPDIR_BASE = File.join(File.dirname(__FILE__), '../../tmp')

  def self.run(repo, opts={})
    fp = FetchPackfile.new(repo, opts)
    fp.run do |repo, path|
      ip = IndexPackfile.new(repo, path, opts)
      ip.run
    end
    repo.needs_index = 'false'
    repo.save
  end

  def self.run_all(opts={})
    Anygit::Model::Repo.all(:needs_index => 'true').each do |repo|
      run(repo, opts)
    end
  end

  module Common
    def set_tmpdir_name
      @tmpdir = File.join(TMPDIR_BASE, "#{@repo.id}-#{Time.now.to_i}-#{rand}")
    end
  end

  class FetchPackfile
    include Common

    def initialize(repo, opts)
      @repo = repo
      @opts = opts

      set_tmpdir_name

      Anygit.log.info("Initing useless repo at #{@tmpdir}")
      @git_repo = Rugged::Repository.init_at(@tmpdir, true)
    end

    def run(&blk)
      path = fetch
      # For some reason, my code requires the index to be built. I
      # suspect there's something with the mwindow stuff I removed,
      # but haven't had time to poke yet.
      sha1 = index(path)
      new_path = fixup_pack_name(path, sha1)
      blk.call(@repo, new_path) if blk
      cleanup unless @opts[:dont_delete]
      new_path
    end

    def fetch
      Anygit.log.info("Fetching all refs from #{@repo.url}")
      r = Rugged::Remote.new(@git_repo, @repo.url)
      r.connect(:fetch)
      r.download
    end

    def index(path)
      Anygit.log.info("Building index for #{path}. This could take a while.")
      Rugged::Index.index_pack(path)
    end

    def fixup_pack_name(path, sha1)
      new_path = File.join(File.dirname(path), "pack-#{sha1}.pack")
      FileUtils.mv(path, new_path)
      Anygit.log.info("Moving #{path} -> #{new_path}")
      new_path
    end

    def cleanup
      Anygit.log.info("Nuking #{@tmpdir}")
      FileUtils.rm_r(@tmpdir)
    end
  end

  class IndexPackfile
    include Common

    def initialize(repo, path, opts)
      @repo = repo
      @path = path
      @opts = opts

      @create ||= {}

      set_tmpdir_name

      Anygit.log.info("Storing mysql outfiles in #{@tmpdir}")
      Dir.mkdir(@tmpdir)
    end

    def run
      build_dumps
      close_files
      load_dumps
      delete_dumps unless @opts[:dont_delete]
    end

    def build_dumps
      start = Time.now

      Rugged::Index.iterate_packfile(@path) do |processed, total, type, sha1|
        if processed % 100 == 0
          if (elapsed = Time.now - start) > 0.1
            rps = processed / elapsed
            remaining = (total - processed) / rps
            percent = (100.0 * processed) / total
            Anygit.log.info("Processed #{processed} / #{total} objects (#{percent.to_i}%) in #{format_time(elapsed)}. That's #{rps} records per second, so there should be about #{format_time(remaining)} remaining")
          end
        end

        store_object(type, sha1)
      end
    end

    def close_files
      @create.each do |table, spec|
        path = spec[:file].path
        Anygit.log.info("Closing file for #{table} (#{path})")
        spec[:file].close
      end
    end

    def load_dumps
      @create.each do |table, spec|
        path = spec[:file].path
        Anygit.log.info("Loading #{table} (#{path})")
        # TODO: use better subprocess interface
        `mysql -u root anygit < #{path}`
      end
    end

    def delete_dumps
      Anygit.log.info("Deleting tmpdir (#{@tmpdir})")
      FileUtils.rm_r(@tmpdir)
    end

    private

    def store_object(type, sha1)
      wrap_duplicates do
        create(Anygit::Model::GitObject,
          :type => type,
          :sha1 => Anygit::Util.sha1_to_bytes(sha1)
          )
      end

      wrap_duplicates do
        create(Anygit::Model::ObjectRepo,
          :sha1 => Anygit::Util.sha1_to_bytes(sha1),
          :repo_id => @repo.id
          )
      end
    end

    def wrap_duplicates(&blk)
      begin
        blk.call
      rescue DataObjects::IntegrityError => e
        Anygit.log.debug("Attempt to make duplicate object: #{e.message}")
      end
    end

    def format_time(a)
      a = a.to_i

      case a
      when 0 then 'no time'
      when 1 then 'a second'
      when 2..59 then a.to_s+' seconds'
      when 60..119 then 'a minute' #120 = 2 minutes
      when 120..3540 then (a/60).to_i.to_s+ ' minutes'
      when 3541..7100 then 'an hour' # 3600 = 1 hour
      when 7101..82800 then ((a+99)/3600).to_i.to_s+ ' hours'
      when 82801..172000 then 'tomorrow' # 86400 = 1 day
      when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+ ' days'
      when 518400..1036800 then 'a week'
      else return (a/518400).to_s + ' weeks'
      end
    end

    def create(klass, data)
      table = Anygit::Util.validate_table_name(klass.storage_name)
      keys = data.keys.sort_by {|k| k.to_s}
      unless @create.include?(table)
        f = File.open(File.join(@tmpdir, table + '.sql'), 'w')
        f.write("INSERT IGNORE INTO #{table} (#{keys.map {|k| Anygit::Util.sql_column_name_quote(k) }.join(', ')}) VALUES")
        @create[table] = {:file => f, :keys => keys, :count => 0}
      end

      spec = @create[table]
      raise "Inconsistent keys: data has keys #{keys.inspect}, while table has keys #{spec[:keys].inspect}" unless spec[:keys] == keys

      if spec[:count] > 0
        spec[:file].write(',')
      end
      spec[:count] += 1

      spec[:file].write("(#{keys.map {|k| Anygit::Util.sql_value_quote(data[k])}.join(', ')})")
    end
  end
end
