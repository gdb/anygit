require 'logger'

require 'rubygems'
require 'bundler/setup'

require 'rugged'

$:.unshift(File.dirname(__FILE__))

module Anygit
  @@log = Logger.new($stdout)
  @@log.level = Logger::INFO

  def self.log
    @@log
  end
end

require 'anygit/indexer'
require 'anygit/model'
require 'anygit/util'
require 'anygit/web_interface'
