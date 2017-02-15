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
      begin
        call_command('mongostat --version')
      rescue Errno::ENOENT
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
          stat = parse_line(line)
          replaced_hash = replace_hash_key(stat, 'host', 'hostname')
          router.emit(@tag, Fluent::Engine.now, replaced_hash)
        end
      end
    end

    def parse_line(line)
      begin
        stat = JSON.parse(line.delete('*')).values[0]
      rescue JSON::ParserError
        raise ParserError, 'response json parse error'
      end

      if stat.has_key?('error')
        return stat
      end

      if stat.has_key?('command')
        stat['command'] = stat['command'].split('|')[0].to_i
      end

      if stat.has_key?('arw')
        arw = stat['arw'].split('|')
        stat['arw'] = {'ar' => arw[0].to_i, 'aw' => arw[1].to_i}
      elsif stat.has_key?('ar|aw')
        arw = stat['ar|aw'].split('|')
        stat.delete('ar|aw')
        stat['arw'] = {'ar' => arw[0].to_i, 'aw' => arw[1].to_i}
      end

      if stat.has_key?('qrw')
        qrw = stat['qrw'].split('|')
        stat['qrw'] = {'qr' => qrw[0].to_i, 'qw' => qrw[1].to_i}
      elsif stat.has_key?('qr|qw')
        qrw = stat['qr|qw'].split('|')
        stat.delete('qr|qw')
        stat['qrw'] = {'qr' => qrw[0].to_i, 'qw' => qrw[1].to_i}
      end

      if stat.has_key?('netIn')
        stat = replace_hash_key(stat, 'netIn', 'net_in')
      end

      if stat.has_key?('netOut')
        stat = replace_hash_key(stat, 'netOut', 'net_out')
      end

      stat['conn'] = stat['conn'].to_i if stat.has_key?('conn')
      stat['delete'] = stat['delete'].to_i  if stat.has_key?('delete')
      stat['flushes'] = stat['flushes'].to_i  if stat.has_key?('flushes')
      stat['getmore'] = stat['getmore'].to_i  if stat.has_key?('getmore')
      stat['insert'] = stat['insert'].to_i  if stat.has_key?('insert')
      stat['query'] = stat['query'].to_i  if stat.has_key?('query')
      stat['update'] = stat['update'].to_i  if stat.has_key?('update')
      stat['dirty'] = stat['dirty'].to_f  if stat.has_key?('dirty')
      stat['used'] = stat['used'].to_f  if stat.has_key?('used')

      return stat
    end

    def replace_hash_key(hash, old_key, new_key)
      hash[new_key] = hash.delete(old_key)
      return hash
    end

    def call_command(command)
      `#{command}`
    end

  end
end
