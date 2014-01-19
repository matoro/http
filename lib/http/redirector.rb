module HTTP
  class Redirector
    # Notifies that we reached max allowed redirect hops
    class TooManyRedirectsError < RuntimeError; end

    # Notifies that following redirects got into an endless loop
    class EndlessRedirectError < TooManyRedirectsError; end

    # HTTP status codes which indicate redirects
    REDIRECT_CODES = [300, 301, 302, 303, 307].freeze

    # Last request
    attr_reader :request

    # Last response
    attr_reader :response

    # :nodoc:
    def initialize(max_redirects)
      @max_redirects = max_redirects
    end

    # Follows redirects until non-redirect response found
    def perform(request, response, &block)
      reset(request, response)
      follow(&block)
    end

  private

    # Reset redirector state
    def reset(request, response)
      @request, @response = request, response
      @visited = []
    end

    # Follow redirects
    def follow
      while REDIRECT_CODES.include?(response.code)
        fail EndlessRedirectError if @visited.include? request.uri
        @visited << request.uri

        fail TooManyRedirectsError if too_many_hops?

        uri = response.headers['Location']
        fail StateError, 'no Location header in redirect' unless uri

        @request  = @request.redirect(uri)
        @response = yield @request
      end

      response
    end

    # Check if we reached max amount of redirect hops
    def too_many_hops?
      return false if @max_redirects.is_a?(TrueClass)
      @max_redirects.to_i < @visited.count
    end
  end
end
