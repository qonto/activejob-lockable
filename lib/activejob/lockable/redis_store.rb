module ActiveJob
  module Lockable
    class RedisStore
      class << self
        def set(cache_key, cache_value, options = {})
          ActiveJob::Lockable.redis.set(cache_key, cache_value, options)
        end

        def exists?(cache_key)
          ActiveJob::Lockable.redis.exists(cache_key)
        end

        def ttl(cache_key)
          ActiveJob::Lockable.redis.ttl(cache_key)
        end

        def del(cache_key)
          ActiveJob::Lockable.redis.del(cache_key)
        end
      end
    end
  end
end
