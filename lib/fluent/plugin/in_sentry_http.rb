require 'fluent/plugin/in_http'

module Fluent
  class SentryHttpInput < HttpInput
    Plugin.register_input('sentry_http', self)

    config_param :tag, :string
    config_param :format, :string, :default => 'sentry_http'

    def on_request(path_info, params)
      begin
        time, record = parse_params(params)

        # Skip nil record
        if record.nil?
          return ['200 OK', {'Content-type' => 'text/plain'}, '']
        end

        if @add_http_headers
          params.each_pair { |k, v|
            if k.start_with?('HTTP_')
              record[k] = v
            end
          }
        end

        if @add_remote_addr
          record['REMOTE_ADDR'] = params['REMOTE_ADDR']
        end
      rescue
        return ['400 Bad Request', {'Content-type' => 'text/plain'}, "400 Bad Request\n#{$!}\n"]
      end

      begin
        router.emit(@tag, time, record)
      rescue
        return ['500 Internal Server Error', {'Content-type' => 'text/plain'}, "500 Internal Server Error\n#{$!}\n"]
      end

      return ['200 OK', {'Content-type' => 'text/plain'}, '']
    end 

    private

    def parse_params_with_parser(params)
      if content = params[EVENT_RECORD_PARAMETER]
          @parser.parse(content) { |time, record|
            raise "Received event is not #{@format}: #{content}" if record.nil?
            record['tag'] ||= @tag
            record['time'] ||= time
            return time, record
          }
      else
        raise "'#{EVENT_RECORD_PARAMETER}' parameter is required"
      end
    end
  end
end
