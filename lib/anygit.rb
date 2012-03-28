require 'logger'
require 'rubygems'
require 'rugged'

$:.unshift(File.dirname(__FILE__))

require 'anygit/model'
require 'anygit/util'
require 'anygit/web_interface'

module Anygit
  @@log = Logger.new($stdout)
  @@log.level = Logger::INFO

  def self.log
    @@log
  end
end
