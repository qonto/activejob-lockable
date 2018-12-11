require 'activejob/lockable/redis_store'

module ActiveJob
  module Lockable
    extend ActiveSupport::Concern

    module ClassMethods
      def on_locked(action)
        self.on_locked_action = action
      end
    end

    included do
      attr_reader :options
      class_attribute :on_locked_action

      def enqueue(options = {})
        @options = options
        if locked?
          logger.info "job is locked, expires in #{locked_ttl} second"
          send(on_locked_action) if on_locked_action && respond_to?(on_locked_action)
        else
          lock!
          super(options)
        end
      end

      def lock!
        return if lock_period.to_i <= 0
        logger.info "locked with #{lock_key} for #{lock_period} seconds. Job_id: #{self.job_id} class_name: #{self.class}"
        begin
          ActiveJob::Lockable::RedisStore.setex(lock_key, lock_period, self.job_id)
        rescue => e
          logger.info "EXCEPTION: locked with #{lock_key} for #{lock_period} seconds. Job_id: #{self.job_id} class_name: #{self.class}"
          raise e
        end
      end

      def unlock!
        return unless locked?
        logger.info "unlocked with #{lock_key}. Job_id: #{self.job_id} class_name: #{self.class}"
        ActiveJob::Lockable::RedisStore.del(lock_key)
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
        options[:lock]
      end
    end
  end
end
