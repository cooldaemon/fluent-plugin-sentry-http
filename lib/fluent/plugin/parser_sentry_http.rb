require 'base64'
require 'zlib'
require 'oj'

module Fluent
  class TextParser
    class SentryHttpParser < Parser
      Plugin.register_parser('sentry_http', self)

      config_param :json_parse, :bool, :default => true
      config_param :field_name, :string, :default => 'message'

      def initialize
        super
      end
 
      def configure(conf)
        super
      end

      def parse(text)
        message = Zlib::Inflate.inflate(Base64.decode64(text))
        record = Oj.load(message, :mode => :compat)

        record_time = record['timestamp']
        time = record_time.nil? ? Engine.now : Time.parse(record_time).to_i

        record = {@field_name => message} unless @json_parse

        yield time, record
      rescue => e
        $log.warn "parse error: #{e.message}"
        yield nil, nil
      end
    end
  end
end
