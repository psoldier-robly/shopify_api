module ShopifyAPI
  class ApiVersion
    class UnknownVersion < StandardError; end

    class NoVersion < ApiVersion
      API_PREFIX = '/admin/'.freeze

      def initialize
        @version_name = "no_version"
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

    def self.coerce_to_version(version_or_name)
      return version_or_name if version_or_name.kind_of?(ApiVersion)

      @versions ||= {}
      @versions.fetch(version_or_name.to_s) do
        raise UnknownVersion, "#{version_or_name} is not in the defined version set: #{@versions.keys.join(', ')}"
      end
    end

    def self.define_version(version)
      @versions ||= {}

      @versions[version.name] = version
    end

    def self.clear_defined_versions
      @versions = {}
    end

    def self.define_known_versions
      define_version(NoVersion.new)
      define_version(Unstable.new)
    end

    def to_s
      @version_name
    end
    alias :name :to_s

    def inspect
      @version_name
    end

    def ==(other)
      other.class == self.class && to_s == other.to_s
    end

    def hash
      version_name.hash
    end

    def ==(other)
      other.class == self.class && to_s == other.to_s
    end

    def hash
      version_name.hash
    end

    def construct_api_path(path)
      raise NotImplementedError
    end

    def construct_graphql_path
      raise NotImplementedError
    end
  end
end

