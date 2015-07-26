require 'fluent/plugin/in_http'

module Fluent
  class SentryHttpInput < HttpInput
    Plugin.register_input('sentry_http', self)

    config_param :format, :string, :default => 'sentry_http'

    def initialize
      super
      @mapping = {}
    end

    def configure(conf)
      super
      conf.elements.select {|element|
        element.name == 'application'
      }.each do |element|
        @mapping[element.arg] = {
          'tag' => element['tag'],
          'user' => element['user'],
          'pass' => element['pass'],
        }
      end
    end

    def on_request(path_info, params)
      begin
        application = @mapping[path_info.split('/')[2]]  # /api/999/store/
        raise 'not found' unless application
      rescue
        return ['404 Not Found', {'Content-type' => 'text/plain'}, '']
      end

      begin
        user, pass = get_auth_info(params)
        raise 'unauthorized' unless application['user'] == user and application['pass'] == pass
      rescue
        return ['401 Unauthorized', {'Content-type' => 'text/plain'}, '']
      end

      begin
        time, record = parse_params(params)
        raise 'Record not found' if record.nil?

        record['tag'] = application['tag']
        record['time'] = time

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
        router.emit(application['tag'], time, record)
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
            return time, record
          }
      else
        raise "'#{EVENT_RECORD_PARAMETER}' parameter is required"
      end
    end

    def get_auth_info(params)
      user = nil
      pass = nil
      params['HTTP_X_SENTRY_AUTH'].split(', ').each do |element|
        key, value = element.split('=')
        case key
        when 'sentry_key'
          user = value
        when 'sentry_secret'
          pass = value
        end
      end
      return user, pass
    end
  end
end
