module ActiveJob
  module Lockable
    class RedisStore
      class << self
        def setex(cache_key, expiration, cache_value)
          ActiveJob::Lockable.redis.setex(cache_key, expiration, cache_value)
        end

        def exists?(cache_key)
          ActiveJob::Lockable.redis.exists(cache_key)
        end

        def ttl(cache_key)
          ActiveJob::Lockable.redis.ttl(cache_key)
        end
      end
    end
  end
end
