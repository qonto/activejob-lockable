require 'activejob/lockable/redis_store'

module ActiveJob
  module Lockable
    extend ActiveSupport::Concern

    module ClassMethods
      def lock_for(lock_period)
        @lock_period = lock_period
      end

      def lock_period
        @lock_period
      end

      def on_locked(action)
        @on_locked = action
      end

      def on_locked_action
        @on_locked
      end

      def set(options)
        lock_for(options[:lock])
        super(options)
      end
    end

    included do
      around_enqueue do |job, block|
        tag_logger(job.class.name, job.job_id) do
          if locked?
            logger.info "job is locked, expires in #{locked_ttl} second"
            send(on_locked_action) if on_locked_action && respond_to?(on_locked_action)
          else
            lock!
            block.call
          end
          lock_for(nil) # resets instance variable to avoid further locks without any reason when set(lock: N) is used
        end
      end

      def lock!
        return if lock_period.to_i <= 0
        logger.info "locked with #{lock_key} for #{lock_period.to_i} seconds before lock! job_id: #{self.job_id} class_name: #{self.class}"
        begin
          ActiveJob::Lockable::RedisStore.setex(lock_key, lock_period.to_i, self.job_id)
        rescue => e
          logger.info "locked with #{lock_key} for #{lock_period.to_i} seconds after lock! job_id: #{self.job_id} class_name: #{self.class}"
          raise e
        end
      end

      def lock_key
        md5 = Digest::MD5.hexdigest(self.arguments.join)
        "#{self.class.name.downcase}:#{md5}"
      end

      def locked?
        ActiveJob::Lockable::RedisStore.exists?(lock_key)
      end

      def locked_ttl
        ActiveJob::Lockable::RedisStore.ttl(lock_key)
      end

      private

      def lock_period
        self.class.lock_period
      end

      def on_locked_action
        self.class.on_locked_action
      end

      def lock_for(lock_period)
        self.class.lock_for(lock_period)
      end
    end
  end
end
