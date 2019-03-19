module ShopifyAPI
  class ApiVersion
    class NoVersion < ApiVersion
      API_PREFIX = '/admin/'.freeze

      def initialize
        @version_name = "no version"
      end

      def construct_api_path(path)
        "#{API_PREFIX}#{path}"
      end

      def construct_graphql_path
        '/admin/api/graphql.json'
      end
    end

    class Unstable < ApiVersion
      API_PREFIX = '/admin/api/unstable/'.freeze

      def initialize
        @version_name = "unstable"
      end

      def construct_api_path(path)
        "#{API_PREFIX}#{path}"
      end

      def construct_graphql_path
        construct_api_path('graphql.json')
      end
    end

    def self.no_version
      NoVersion.new
    end

    def self.unstable
      Unstable.new
    end

    def to_s
      @version_name
    end

    def inspect
      @version_name
    end

    def construct_api_path(path)
      raise NotImplementedError
    end

    def construct_graphql_path
      raise NotImplementedError
    end
  end
end
