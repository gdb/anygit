require 'pathname'
require 'sinatra/base'

module Anygit
  class WebInterface < Sinatra::Base
    set :root, Pathname.new(File.join(File.dirname(__FILE__), '../..')).realpath

    get '/q/:sha1' do
      erb :q
    end
  end
end
