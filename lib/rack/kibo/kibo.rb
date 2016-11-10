require 'rack'
require 'json'

class SomethingTest

end

module Rack
  ##
  # Rack Middleware which presents a clean API to JSON responses
  class Kibo
    ##
    # Regex to locate an API version in the path. Able to find the following
    # - /path/api/1/something => 1
    # - /path/api/V2/something => 2
    # - /api/v13/omething => 13
    # - /something/else/134/ => 0
    API_PARSE_REGEX = /.*\/api\/[vV]?(\d*)\/?/
    ##
    # Standard JSON content-type
    JSON_CONTENT_TYPE = "application/json"

    ##
    # Creates a new instance of the CleanApi middleware
    # +app+: The rack app
    # +options+: Hash of options to pass to the middleware
    def initialize(app, options={})
      @app = app
      @options = options
    end

    ##
    # Rack Middleware entry-point
    def call(env)
      result = @app.call(env)
      wrap_response env, result
    rescue StandardError => e
      wrap_response env, create_error_response(e, env, result)
    end

    private

    ##
    # Fetches the 'HTTP_ACCEPT' option from +env+
    def request_accept(env)
      env["HTTP_ACCEPT"]
    end

    ##
    # Fetches the 'PATH_INFO' rack variable from +env+
    # Optionally will find and prioritize the 'REQUEST_PATH' 
    # if available
    def request_path(env)
      env["REQUEST_PATH"] || env["PATH_INFO"]
    end

    ##
    # Takes the output from the rack app and optionally
    # wraps the +response+ with a simple JSON API structure
    def wrap_response(env, response)
      return response unless should_wrap_response?(env, response)
      rs = {
        :success => is_successful_http_status_code?(response[0]),
        :responded_at => Time.now.utc,
        :version => parse_api_version(env),
        :location => request_path(env),
        :body => create_payload(response[2])
      }
      response[2] = [ rs.to_json ]
      response[1]["Content-Length"] = response[2][0].length.to_s

      # TODO: support an option to allow user to emit original status codes
      
      response[0] = 200 unless rs[:success]
      response
    end

    ##
    # Convert exceptions into a proper response
    def create_error_response(error, env, result)
      rsp_env = {}
      response = 'Error'
      if should_wrap_response?(env, result)
        server_result = nil
        if result
          env = result[1]
          server_result = result[2]
        end
        response = create_error_json(error, server_result)
      end
      error_result = [500, rsp_env, [response]]
    end

    ##
    # Generates the 'payload' element of the API response
    def create_payload(response_data)
      payload = []
      response_data.each do |data|
        payload << JSON.parse(data)
      end

      nil if payload.length == 0
      payload if payload.length > 1
      payload[0] if payload.length == 1
    end

    ##
    # Parses the API version from the request path
    def parse_api_version(env)
      matches = API_PARSE_REGEX.match(request_path(env))
      return 0 unless matches
      matches.captures[0].to_i
    end

    ##
    # Generates an error response payload
    def create_error_json(error, data)
      result = {
        :error => {
          :message => 'Error'
        }
      }
      if @options[:expose_errors]
        result[:error][:message] = error.message
        result[:error][:data] = data
      end
      result.to_json
    end

    ##
    # Determines if the HTTP Status code is considered
    # a successful response
    def is_successful_http_status_code?(code)
      code < 400
    end

    ##
    # Determines if the response should be wrapped in
    # the CleanApi object
    def should_wrap_response?(env, response)
      client_request = is_supported_content_type? request_accept(env)
      server_response = response_should_be_json? response
      server_response || client_request
    end

    ##
    # Determines if the response Content-Type is supposed
    # to be wrapped in the CleanApi object
    def response_should_be_json?(response)
      return false unless response
      is_supported_content_type? response[1]["Content-Type"]
    end

    ##
    # Determines if the +content_type+ dictates that the
    # response should be wrapped in the CleanApi
    def is_supported_content_type?(content_type)
      # TODO: Should we allow user-defined accept-encodings?
      content_type == JSON_CONTENT_TYPE
    end

  end
end
