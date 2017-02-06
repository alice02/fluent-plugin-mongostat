require 'fluent/plugin/input'
require 'open3'
require 'json'


module Fluent::Plugin
  class MongostatInput < Fluent::Plugin::Input

    Fluent::Plugin.register_input('mongostat', self)

    def initialize
      super
    end

    unless method_defined?(:router)
      define_method('router') { Fluent::Engine }
    end


    desc 'The command line options of mongostat'
    config_param :option, :string, default: '--discover'
    desc 'The interval of refreshing'
    config_param :refresh_interval, :time, default: 10
    desc 'The tag of the event'
    config_param :tag, :string

    def configure(conf)
      super
      @command = %Q[ mongostat #{@option} --json #{@refresh_interval}]
      @hostname = `hostname`.chomp!
    end

    def start
      super
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      Thread.kill(@thread)
    end

    def run
      Open3.popen3(@command) do |i, o, e, w|
        o.each do |line|
          stat = JSON.parse(line.delete!('*'))
          router.emit(@tag, Fluent::Engine.now, stat)
        end
      end
    end

  end
end
