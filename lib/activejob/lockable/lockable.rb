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
          logger.info "Job is locked, expires in #{locked_ttl} second(s)"
          send(on_locked_action) if on_locked_action && respond_to?(on_locked_action)
        else
          lock!
          super(options)
        end
      end

      def lock!
        return if lock_period.to_i <= 0
        logger.info "Acquiring lock #{lock_extra_info}"
        begin
          # `:ex => Fixnum`: Set the specified expire time, in seconds.
          # `:nx => true`: Only set the key if it does not already exist.
          lock_acquired = ActiveJob::Lockable::RedisStore.set(
            lock_key,
            self.job_id,
            { ex: lock_period.to_i, nx: true }
          )
          raise "Could not acquire lock #{lock_extra_info}" unless lock_acquired
        rescue StandardError => e
          logger.info "EXCEPTION acquiring lock #{lock_extra_info}"
          raise
        end
      end

      def unlock!
        return unless locked?
        logger.info "Releasing lock #{lock_extra_info}"
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
        options&.fetch(:lock, 0).to_i
      end

      def lock_extra_info
        "[key #{lock_key}] [seconds #{lock_period.to_i}] [job_id #{self.job_id}] [class_name: #{self.class}]"
      end
    end
  end
end
