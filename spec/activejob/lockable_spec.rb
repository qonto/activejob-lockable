require 'spec_helper'

RSpec.describe ActiveJob::Lockable, type: :job do
  class LockableJob < ActiveJob::Base
    on_locked :call_method

    def call_method
      raise "argument #{self.arguments} is locked"
    end

    def perform(argument_id)
    end
  end

  subject { LockableJob }
  let(:argument_id) { SecureRandom.uuid }

  context 'when lock' do
    context 'is set' do
      it 'should raise exception when argument is locked' do
        expect{ subject.set(lock: 2).perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        expect{ subject.set(lock: 2).perform_later(argument_id) }.to raise_error("argument #{[argument_id]} is locked")
      end
    end

    context 'is not set' do
      before do
        allow_any_instance_of(subject).to receive(:on_locked_action).and_return(nil)
      end

      it 'should not enqueue and raise no exception' do
        expect{ subject.set(lock: 2).perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        expect{ subject.set(lock: 2).perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(0)
      end
    end
  end

  context '#lock_period' do
    context 'without value' do
      it 'should not be lockable' do
        expect{ subject.perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        expect{ subject.perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end

    context 'with value' do
      before do
        allow_any_instance_of(subject).to receive(:on_locked_action).and_return(nil)
      end

      it 'should be lockable' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:setex)
          .with(String, 10.seconds, any_args)
        subject.set(lock: 10.seconds).perform_later(argument_id)

        expect(ActiveJob::Lockable::RedisStore).to receive(:setex)
          .with(String, 2.seconds, any_args)
        subject.set(lock: 2.seconds).perform_later(argument_id)

        expect(ActiveJob::Lockable::RedisStore).not_to receive(:setex)
          .with(any_args)
        subject.perform_later(argument_id)
      end
    end

    context 'with overridden method' do
      class CustomLockablePeriodJob < LockableJob
        on_locked nil

        def lock_period
          5.seconds
        end
      end

      subject { CustomLockablePeriodJob }

      it 'should lock and always use default' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:setex)
          .with(String, 5.seconds, any_args)
          .exactly(3)

        subject.set(lock: 10.seconds).perform_later(argument_id)
        subject.set(lock: 2.seconds).perform_later(argument_id)
        subject.perform_later(argument_id)
      end
    end
  end

  context '#lock_key' do

    context 'by default' do
      let(:lock_key) { "#{subject.name.downcase}:#{Digest::MD5.hexdigest([argument_id].join)}" }
      it 'should match md5 of argument' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:setex)
          .with(lock_key, 2.seconds, any_args)
        subject.set(lock: 2.seconds).perform_later(argument_id)
      end
    end

    context 'overridden' do
      class CustomLockKeyJob < LockableJob
        on_locked nil

        def lock_key
          'custom-lock-key'
        end
      end

      let(:lock_key) { 'custom-lock-key' }

      subject { CustomLockKeyJob }

      it 'should match the value of method' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:setex)
          .with(lock_key, 2.seconds, any_args)
        subject.set(lock: 2.seconds).perform_later(argument_id)
      end
    end
  end
end
