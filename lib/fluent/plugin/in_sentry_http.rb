require 'fluent/plugin/in_http'

module Fluent
  class SentryHttpInput < HttpInput
    Plugin.register_input('sentry_http', self)

    config_param :format, :string, :default => 'sentry_http'

    attr_reader :mapping

    def initialize
      super
      @mapping = {}
    end

    def configure(conf)
      super
      conf.elements.select {|element|
        element.name == 'project'
      }.each do |element|
        @mapping[element.arg] = {
          'tag' => element['tag'],
          'key' => element['key'],
          'secret' => element['secret'],
        }
      end
    end

    def on_request(path_info, params)
      begin
        project = @mapping[path_info.split('/')[2]]  # /api/999/store/
        raise 'not found' unless project
      rescue
        return ['404 Not Found', {'Content-type' => 'text/plain'}, '']
      end

      begin
        key, secret = get_auth_info(params)
        raise 'unauthorized' unless project['key'] == key and project['secret'] == secret
      rescue
        return ['401 Unauthorized', {'Content-type' => 'text/plain'}, '']
      end

      begin
        time, record = parse_params(params)
        raise 'Record not found' if record.nil?

        record['tag'] = project['tag']
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
        router.emit(project['tag'], time, record)
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
      sentry_key = nil
      sentry_secret = nil
      params['HTTP_X_SENTRY_AUTH'].split(', ').each do |element|
        key, value = element.split('=')
        case key
        when 'sentry_key'
          sentry_key = value
        when 'sentry_secret'
          sentry_secret = value
        end
      end
      return sentry_key, sentry_secret
    end
  end
end
