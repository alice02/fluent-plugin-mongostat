require 'open3'
require 'json'

module Fluent
  class MongostatInput < Input

    Fluent::Plugin.register_input('mongostat', self)

    def initialize
      super
    end

    unless method_defined?(:router)
      define_method('router') { Fluent::Engine }
    end

    desc 'The command line options of mongostat'
    config_param :option, :string, default: ''
    desc 'The interval of refreshing'
    config_param :refresh_interval, :time, default: 10
    desc 'The tag of the event'
    config_param :tag, :string

    def configure(conf)
      super
      base_command = "mongostat"
      begin
        `#{base_command} --version`
      rescue Errno::ENOENT
        raise ConfigError, "'#{base_command}' command not found."
      end

      @command = %(#{base_command} #{@option} --json #{@refresh_interval})
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
          router.emit(@tag, Fluent::Engine.now, stat[stat.keys[0]])
        end
      end
    end

  end
end
