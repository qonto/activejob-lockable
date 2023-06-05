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
        return trigger_on_locked_action unless lock!

        super(options)
      end

      def lock!
        return true if lock_period.to_i <= 0
        logger.info "Acquiring lock #{lock_extra_info}"
        # `:ex => Fixnum`: Set the specified expire time, in seconds.
        # `:nx => true`: Only set the key if it does not already exist.
        # Returns boolean, lock acquired or not
        ActiveJob::Lockable::RedisStore.set(
          lock_key,
          self.job_id,
          { ex: lock_period.to_i, nx: true }
        )
      rescue StandardError => e
        logger.info "EXCEPTION acquiring lock #{lock_extra_info}"
        raise
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
        ActiveJob::Lockable::RedisStore.exists?(lock_key) != 0
      end

      def locked_ttl
        ActiveJob::Lockable::RedisStore.ttl(lock_key)
      end

      private

      def lock_period
        return 0 unless options

        options[:lock].to_i
      end

      def trigger_on_locked_action
        logger.info "Job is locked, expires in #{locked_ttl} second(s)"
        public_send(on_locked_action) if on_locked_action && respond_to?(on_locked_action)
      end

      def lock_extra_info
        "[key #{lock_key}] [seconds #{lock_period.to_i}] [job_id #{self.job_id}] [class_name: #{self.class}]"
      end
    end
  end
end
