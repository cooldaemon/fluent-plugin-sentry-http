require 'helper'
require 'net/http'
require 'base64'
require 'zlib'
require 'oj'

class SentryHttpInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  HOST = '127.0.0.1'
  PROJECT = 999
  TAG = 'from.raven'
  KEY = 'test_key'
  SECRET = 'test_secret'

  CONFIG = %[
    port #{PORT}
    bind #{HOST}

    <project #{PROJECT}>
      tag #{TAG}
      key #{KEY}
      secret #{SECRET}
    </project>
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SentryHttpInput).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal PORT, d.instance.port
    assert_equal '127.0.0.1', d.instance.bind

    project = d.instance.mapping[PROJECT.to_s]
    assert_equal TAG, project['tag']
    assert_equal KEY, project['key']
    assert_equal SECRET, project['secret']
  end

  def test_success_request
    time, record, expect_record = create_time_and_record
    d = create_driver
    d.expect_emit TAG, time, expect_record
    d.run do
      res = post_record(
        PROJECT,
        create_headers(time, KEY, SECRET),
        record_to_payload(record))
      assert_equal '200', res.code
    end
  end

  def test_not_found_request
    time, record, expect_record = create_time_and_record
    d = create_driver
    d.run do
      res = post_record(
        998,
        create_headers(time, KEY, SECRET),
        record_to_payload(record))
      assert_equal '404', res.code
    end
  end

  def test_unauthorized_request
    time, record, expect_record = create_time_and_record
    d = create_driver
    d.run do
      res = post_record(
        PROJECT,
        create_headers(time, 'ham', SECRET),
        record_to_payload(record))
      assert_equal '401', res.code

      res = post_record(
        PROJECT,
        create_headers(time, KEY, 'egg'),
        record_to_payload(record))
      assert_equal '401', res.code
    end
  end

  def test_bad_request
    time, record, expect_record = create_time_and_record
    d = create_driver
    d.run do
      res = post_record(
        PROJECT,
        create_headers(time, KEY, SECRET),
        'spam')
      assert_equal '400', res.code
    end
  end

  private

  def create_time_and_record
    timestamp = '2015-07-26T09:24:30Z'
    time = Time.parse(timestamp).to_i
    record = create_record(timestamp)
    expect_record = record.merge({'tag' => TAG, 'time' => time})
    return time, record, expect_record
  end

  def create_headers(time, key, secret)
    {
      'X-Sentry-Auth' => "Sentry sentry_timestamp=#{time}, sentry_client=raven-python/5.2.0, sentry_version=6, sentry_key=#{key}, sentry_secret=#{secret}",
      'Content-Type' => 'application/octet-stream',
      'User-Agent' => 'raven-python/5.2.0',
    }
  end

  def create_record(timestamp)
    {
      'timestamp' => timestamp,
      'message' => 'test',
    }
  end

  def record_to_payload(record)
    text = Oj.dump(record, :mode => :compat)
    compressed_text = Zlib::Deflate.deflate(text)
    Base64.encode64(compressed_text)
  end

  def post_record(project, headers, payload)
    http = Net::HTTP.new(HOST, PORT)
    req = Net::HTTP::Post.new("/api/#{project}/store/", headers)
    req.body = payload
    http.request(req)
  end
end
