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
  APPLICATION = 999
  TAG = 'from.raven'
  USER = 'test_user'
  PASS = 'test_pass'

  CONFIG = %[
    port #{PORT}
    bind #{HOST}

    <application #{APPLICATION}>
      tag #{TAG}
      user #{USER}
      pass #{PASS}
    </application>
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SentryHttpInput).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal PORT, d.instance.port
    assert_equal '127.0.0.1', d.instance.bind

    application = d.instance.mapping[APPLICATION.to_s]
    assert_equal TAG, application['tag']
    assert_equal USER, application['user']
    assert_equal PASS, application['pass']
  end

  def test_success_request
    d = create_driver
    timestamp = '2015-07-26T09:24:30Z'
    time = Time.parse(timestamp).to_i
    record = create_record(timestamp)
    expect_record = record.merge({'tag' => TAG, 'time' => time})

    d.expect_emit TAG, time, expect_record
    d.run do
      res = post_record(create_headers(time, USER, PASS), record_to_payload(record))
      assert_equal '200', res.code
    end
  end

  def create_headers(time, user, pass)
    {
      'X-Sentry-Auth' => "Sentry sentry_timestamp=#{time}, sentry_client=raven-python/5.2.0, sentry_version=6, sentry_key=#{user}, sentry_secret=#{pass}",
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

  def post_record(headers, payload)
    http = Net::HTTP.new(HOST, PORT)
    req = Net::HTTP::Post.new("/api/#{APPLICATION}/store/", headers)
    req.body = payload
    http.request(req)
  end
end
