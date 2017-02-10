require 'helper'

class MongostatInputTest < Minitest::Test
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  ]

  def create_driver(conf = CONFIG, tag='test', stub = TRUE)
    driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::MongostatInput, tag)
    if stub
      mock_method = MiniTest::Mock.new.expect :call, 'stdout', ["mongostat --version"]
      driver.instance.stub :call_system, mock_method do
        return driver.configure(conf)
      end
    else
      return driver.configure(conf)
    end
  end

  def test_configure
    assert_raises(Fluent::ConfigError) do
      d = create_driver CONFIG, 'test', FALSE
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

  def test_parse_line
    raw_line = '{"localhost:27017":{"arw":"1|0","command":"2|0","conn":"1","delete":"*4","dirty":"0.1%","flushes":"2","getmore":"1","insert":"*3","net_in":"158b","net_out":"44.7k","qrw":"3|1","query":"*10","res":"62.0M","time":"06:32:22","update":"*1","used":"0.3%","vsize":"265M"}}'

    d = create_driver
    parsed_hash = d.instance.parse_line raw_line
    assert_equal parsed_hash['arw'], {'ar'=>'1', 'aw'=>'0'}
    assert_equal parsed_hash['command'], '2'
    assert_equal parsed_hash['conn'], '1'
    assert_equal parsed_hash['delete'], '4'
    assert_equal parsed_hash['dirty'], '0.1%'
    assert_equal parsed_hash['flushes'], '2'
    assert_equal parsed_hash['getmore'], '1'
    assert_equal parsed_hash['insert'], '3'
    assert_equal parsed_hash['net_in'], '158b'
    assert_equal parsed_hash['net_out'], '44.7k'
    assert_equal parsed_hash['qrw'], {'qr'=>'3', 'qw'=>'1'}
    assert_equal parsed_hash['query'], '10'
    assert_equal parsed_hash['res'], '62.0M'
    assert_equal parsed_hash['time'], '06:32:22'
    assert_equal parsed_hash['update'], '1'
    assert_equal parsed_hash['used'], '0.3%'
    assert_equal parsed_hash['vsize'], '265M'
  end

  def test_replace_hash_key
    hash = {'old0'=>'0', 'old1'=>'1'}
    d = create_driver
    new_hash = d.instance.replace_hash_key hash, 'old0', 'new0'
    assert_equal new_hash, {'new0'=>'0', 'old1'=>'1'}
  end

  def test_split_by_pipe
    d = create_driver
    assert_equal d.instance.split_by_pipe('a|b'), ['a', 'b']
  end

end
