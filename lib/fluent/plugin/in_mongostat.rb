require 'fluent/input'
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
    config_param :option, :string, default: nil
    desc 'The interval of refreshing'
    config_param :refresh_interval, :integer, default: 30
    desc 'The tag of the event'
    config_param :tag, :string, default: 'mongostat'

    def configure(conf)
      super

      if !mongostat_exists?
        raise ConfigError, '"mongostat" command not found.'
      end

      @command = %(mongostat #{@option} --json #{@refresh_interval})
    end

    def start
      super
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      super
      Thread.kill(@thread)
    end

    def run
      Open3.popen3(@command) do |i, o, e, w|
        o.each do |line|
          status = parse_line(line)
          router.emit(@tag, Fluent::Engine.now, status)
        end
      end
    end

    def parse_line(line)
      begin
        json_hash = JSON.parse(line.delete('*'))
      rescue JSON::ParserError
        raise ParserError, 'response json parse error'
      end

      status = json_hash.values[0]

      if status.has_key?('error')
        return status
      end

     if status.has_key?('command')
        status['command'] = status['command'].split('|')[0].to_i
      end

      if !status.has_key?('host')
        hostname = json_hash.keys[0]
        status['hostname'] = hostname
      else
        status['hostname'] = status.delete('host')
      end

      if status.has_key?('arw')
        arw = status['arw'].split('|')
        status['arw'] = {'ar' => arw[0].to_i, 'aw' => arw[1].to_i}
      elsif status.has_key?('ar|aw')
        arw = status['ar|aw'].split('|')
        status.delete('ar|aw')
        status['arw'] = {'ar' => arw[0].to_i, 'aw' => arw[1].to_i}
      end

      if status.has_key?('qrw')
        qrw = status['qrw'].split('|')
        status['qrw'] = {'qr' => qrw[0].to_i, 'qw' => qrw[1].to_i}
      elsif status.has_key?('qr|qw')
        qrw = status['qr|qw'].split('|')
        status.delete('qr|qw')
        status['qrw'] = {'qr' => qrw[0].to_i, 'qw' => qrw[1].to_i}
      end

      if status.has_key?('netIn')
        status['net_in'] = status.delete('netIn')
      end

      if status.has_key?('netOut')
        status['net_out'] = status.delete('netOut')
      end

      status['conn'] = status['conn'].to_i if status.has_key?('conn')
      status['delete'] = status['delete'].to_i  if status.has_key?('delete')
      status['flushes'] = status['flushes'].to_i  if status.has_key?('flushes')
      status['getmore'] = status['getmore'].to_i  if status.has_key?('getmore')
      status['insert'] = status['insert'].to_i  if status.has_key?('insert')
      status['query'] = status['query'].to_i  if status.has_key?('query')
      status['update'] = status['update'].to_i  if status.has_key?('update')
      status['dirty'] = status['dirty'].to_f  if status.has_key?('dirty')
      status['used'] = status['used'].to_f  if status.has_key?('used')

      return status
    end

    def mongostat_exists?
      begin
        `mongostat --version`
      rescue Errno::ENOENT
        return false
      end
      return true
    end

  end
end
