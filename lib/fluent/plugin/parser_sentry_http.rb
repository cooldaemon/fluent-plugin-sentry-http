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

        if @json_parse
          record = Oj.load(message, :mode => :compat)
        else
          record = {@field_name => message}
        end

        yield Engine.now, record
      rescue => e
        $log.warn "parse error: #{e.message}"
        yield nil, nil
      end
    end
  end
end
