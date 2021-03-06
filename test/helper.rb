require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Vundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'minitest/autorun'
require 'test/unit'


$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'fluent/test'
unless ENV.has_key?('VERBOSE')
  nulllogger = Object.new
  nulllogger.instance_eval do |obj|
    def method_missing(method, *args)
      # pass
    end
  end
  $log = nulllogger
end

require 'fluent/plugin/in_mongostat'

class Test::Unit::TestCase
end
