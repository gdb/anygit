require 'logger'
require 'rubygems'
require 'rugged'

$:.unshift(File.dirname(__FILE__))

require 'anygit/model'
require 'anygit/util'

module Anygit
  @@log = Logger.new(STDOUT)
  @@log.level = Logger::DEBUG

  def self.log
    @@log
  end
end
