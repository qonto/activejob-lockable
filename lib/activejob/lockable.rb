require 'activejob/lockable/version'
require 'active_support/lazy_load_hooks'

ActiveSupport.on_load :active_job do
  require 'activejob/lockable/lockable'
  ActiveJob::Base::ClassMethods.send(:include, ActiveJob::Lockable::ClassMethods)
  ActiveJob::Base.send(:include, ActiveJob::Lockable)
end

module ActiveJob
  module Lockable
    extend self

    # Accepts:
    #   1. A redis URL (valid for `Redis.new(url: url)`)
    #   2. an options hash compatible with `Redis.new`
    #   3. or a valid Redis instance (one that responds to `#smembers`). Likely,
    #      this will be an instance of either `Redis`, `Redis::Client`,
    #      `Redis::DistRedis`, or `Redis::Namespace`.
    def redis=(server)
      @redis = if server.is_a?(String)
        Redis.new(:url => server, :thread_safe => true)
      elsif server.is_a?(Hash)
        Redis.new(server.merge(:thread_safe => true))
      elsif server.respond_to?(:smembers)
        server
      else
        raise ArgumentError,
          'You must supply a url, options hash or valid Redis connection instance'
      end
    end

    # Returns the current Redis connection, raising an error if it hasn't been created
    def redis
      return @redis if @redis
      raise 'Redis is not configured'
    end
  end
end
