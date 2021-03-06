require 'helper'

class MongostatInputTest < Minitest::Test
  extend Minitest::Spec::DSL

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  ]

  def create_driver(conf = CONFIG, tag = 'test', command_exists = true)
    driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::MongostatInput, tag)
    if command_exists
      mongostat_stub = MiniTest::Mock.new.expect :call, true
      hostname_stub = MiniTest::Mock.new.expect :call, "testhost"
      driver.instance.stub :mongostat_exists?, mongostat_stub do
        driver.instance.stub :get_hostname, hostname_stub do
          return driver.configure(conf)
        end
      end
    else
      stub_method = MiniTest::Mock.new.expect :call, false
      driver.instance.stub :mongostat_exists?, stub_method do
        return driver.configure(conf)
      end
    end
  end

  def test_configure
    assert_raises(Fluent::ConfigError) do
      d = create_driver CONFIG, 'test', false
    end

    d = create_driver %[
      tag mongostat.test
      option --discover
      refresh_interval 1
    ]
    assert_equal 'mongostat.test', d.instance.tag
    assert_equal '--discover', d.instance.option
    assert_equal 1, d.instance.refresh_interval

    d = create_driver
    assert_equal 'mongostat', d.instance.tag
    assert_nil d.instance.option
    assert_equal 30, d.instance.refresh_interval
  end

  let(:mongostat_output) {
    '{"localhost:27017":{"arw":"1|0","command":"2|0","conn":"1","delete":"*4","dirty":"0.1%",' +
      '"flushes":"2","getmore":"1","insert":"*3","net_in":"158b","net_out":"44.7k","qrw":"3|1",' +
      '"query":"*10","res":"62.0M","time":"06:32:22","update":"*1","used":"0.3%","vsize":"265M"}}'
  }

  let(:mongostat_output_with_discover) {
    '{"host1":{"ar|aw":"0|0","command":"9|0","conn":"32","delete":"*0","flushes":"0","getmore":"1",' +
      '"host":"host1","insert":"*0","netIn":"793b","netOut":"44.0k","qr|qw":"0|0","query":"*0",' +
      '"repl":"PRI","res":"1.08G","set":"set1","time":"11:26:11","update":"*0","vsize":"265M"},' +
      '"host2":{"ar|aw":"0|0","command":"15|0","conn":"42","delete":"*0","flushes":"0","getmore":"0",' +
      '"host":"host2","insert":"*0","netIn":"3.90k","netOut":"89.7k","qr|qw":"0|0","query":"23",' +
      '"repl":"SEC","res":"994M","set":"set1","time":"11:26:11","update":"*0","vsize":"265M"}}'
  }

  let(:mongostat_error_output) {
    '2017-02-14T00:30:18.076+0000    Failed: error connecting to db server: no reachable servers'
  }

  let(:mongostat_output_with_no_data) {
    '{"localhost:27017":{"error":"no data received"}}'
  }

  def test_parse_line
    d = create_driver
    parsed_hash = d.instance.parse_line mongostat_output

    assert parsed_hash['command'] != '2|0'
    assert parsed_hash['arw'] != nil
    assert parsed_hash['qrw'] != nil

    assert_equal parsed_hash['arw'], {'ar'=>1, 'aw'=>0}
    assert_equal parsed_hash['command'], 2
    assert_equal parsed_hash['conn'], 1
    assert_equal parsed_hash['delete'], 4
    assert_equal parsed_hash['dirty'], 0.1
    assert_equal parsed_hash['flushes'], 2
    assert_equal parsed_hash['getmore'], 1
    assert_equal parsed_hash['insert'], 3
    assert_equal parsed_hash['net_in'], 158
    assert_equal parsed_hash['net_out'], 44700
    assert_equal parsed_hash['qrw'], {'qr'=>3, 'qw'=>1}
    assert_equal parsed_hash['query'], 10
    assert_equal parsed_hash['res'], 62000000
    assert_equal parsed_hash['time'], '06:32:22'
    assert_equal parsed_hash['update'], 1
    assert_equal parsed_hash['used'], 0.3
    assert_equal parsed_hash['vsize'], 265000000
    assert_equal parsed_hash['hostname'], 'testhost'
  end

  def test_parse_line_with_discover
    d = create_driver
    parsed_hash = d.instance.parse_line mongostat_output_with_discover

    assert parsed_hash['command'] != '9|0'
    assert parsed_hash['arw'] != nil
    assert parsed_hash['qrw'] != nil

    assert_equal parsed_hash['arw'], {'ar'=>0, 'aw'=>0}
    assert_equal parsed_hash['command'], 9
    assert_equal parsed_hash['conn'], 32
    assert_equal parsed_hash['delete'], 0
    assert_equal parsed_hash['flushes'], 0
    assert_equal parsed_hash['getmore'], 1
    assert_equal parsed_hash['insert'], 0
    assert_equal parsed_hash['net_in'], 793
    assert_equal parsed_hash['net_out'], 44000
    assert_equal parsed_hash['qrw'], {'qr'=>0, 'qw'=>0}
    assert_equal parsed_hash['query'], 0
    assert_equal parsed_hash['repl'], 'PRI'
    assert_equal parsed_hash['res'], 1080000000
    assert_equal parsed_hash['set'], 'set1'
    assert_equal parsed_hash['time'], '11:26:11'
    assert_equal parsed_hash['update'], 0
    assert_equal parsed_hash['vsize'], 265000000
    assert_equal parsed_hash['hostname'], 'host1'
  end

  def test_parse_line_with_no_data
    d = create_driver
    parsed_hash = d.instance.parse_line mongostat_output_with_no_data
    assert_equal parsed_hash['error'], 'no data received'
  end

  def test_parse_line_with_error
    d = create_driver
    assert_raises(Fluent::ParserError) do
      parsed_hash = d.instance.parse_line mongostat_error_output
    end
  end

  def test_parse_unit
    d = create_driver
    assert_equal d.instance.parse_unit("140b"), 140
    assert_equal d.instance.parse_unit("140B"), 140
    assert_equal d.instance.parse_unit("14.0k"), 14000
    assert_equal d.instance.parse_unit("14.0K"), 14000
    assert_equal d.instance.parse_unit("14.0m"), 14000000
    assert_equal d.instance.parse_unit("14.0M"), 14000000
    assert_equal d.instance.parse_unit("14.0g"), 14000000000
    assert_equal d.instance.parse_unit("14.0G"), 14000000000
    assert_equal d.instance.parse_unit("14.0t"), 14000000000000
    assert_equal d.instance.parse_unit("14.0T"), 14000000000000
  end

end
