require 'spec_helper'

RSpec.describe ActiveJob::Lockable, type: :job do
  class LockableJob < ActiveJob::Base
    on_locked :call_method

    def call_method
      "on_locked_action called with arguments #{self.arguments}"
    end

    def perform(argument_id)
    end
  end

  subject { LockableJob }
  let(:argument_id) { SecureRandom.uuid }

  describe '#lock!' do
    context 'when Redis store acquires a lock' do
      before do
        allow(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 2, nx: true })
          .and_return(true)
      end

      it 'enqueues the job' do
        expect{ subject.set(lock: 2).perform_later(argument_id) }
          .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end

    context 'when Redis store does not acquire a lock' do
      before do
        allow(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 2, nx: true })
          .and_return(false)
      end

      it 'does not enqueue the job again' do
        expect{ subject.set(lock: 2).perform_later(argument_id) }
          .not_to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size)
      end
    end

    context 'when Redis store encounters an error while acquiring a lock' do
      before do
        allow(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 2, nx: true })
          .and_raise 'Whoops, Redis is offline'
      end

      it 'raises an error' do
        expect{ subject.set(lock: 2).perform_later(argument_id) }
          .to raise_error(StandardError)
      end
    end
  end

  describe ':on_locked_action' do
    context 'when locked' do
      before do
        allow(ActiveJob::Lockable::RedisStore).to receive(:set).and_return(false)
      end

      it 'calls the method' do
        expect(subject.set(lock: 2).perform_later(argument_id))
          .to eq("on_locked_action called with arguments #{[argument_id]}")
      end
    end

    context 'when not locked' do
      before do
        allow(ActiveJob::Lockable::RedisStore).to receive(:set).and_return(true)
      end

      it 'does not call the method' do
        expect(subject.set(lock: 2).perform_later(argument_id))
          .to be_a(LockableJob)
      end
    end
  end

  describe '#unlock!' do
    let(:job) { subject.new(argument_id) }

    context 'when locked' do
      it 'deletes the key for the job' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:del).with(job.lock_key)
        subject.set(lock: 2).perform_later(argument_id)
        job.unlock!
      end

      it 'becomes unlocked' do
        subject.set(lock: 2).perform_later(argument_id)
        job.unlock!
        expect(job.locked?).to eq false
      end
    end

    context 'when not locked' do
      it 'returns directly' do
        expect(ActiveJob::Lockable::RedisStore).not_to receive(:del).with(any_args)
        subject.perform_later(argument_id)
        job.unlock!
      end
    end
  end

  describe '#lock_period' do
    context 'without value' do
      it 'is not lockable' do
        expect{ subject.perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        expect{ subject.perform_later(argument_id) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end

    context 'with value' do
      before do
        allow_any_instance_of(subject).to receive(:on_locked_action).and_return(nil)
      end

      it 'is lockable' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 10, nx: true })
          .and_return(true)
        subject.set(lock: 10.seconds).perform_later(argument_id)

        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 2, nx: true })
          .and_return(true)
        subject.set(lock: 2.seconds).perform_later(argument_id)

        expect(ActiveJob::Lockable::RedisStore).not_to receive(:set)
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

      it 'locks and always use overridden value' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(String, String, { ex: 5, nx: true })
          .and_return(true)
          .exactly(3)

        subject.set(lock: 10.seconds).perform_later(argument_id)
        subject.set(lock: 2.seconds).perform_later(argument_id)
        subject.perform_later(argument_id)
      end
    end
  end

  describe '#lock_key' do
    context 'with default value' do
      let(:lock_key) { "#{subject.name.downcase}:#{Digest::MD5.hexdigest([argument_id].join)}" }
      it 'matches md5 of argument' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(lock_key, String, { ex: 2, nx: true })
          .and_return(true)
        subject.set(lock: 2.seconds).perform_later(argument_id)
      end

      it 'matches md5 of argument_id even with an added nil param' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(lock_key, String, { ex: 2, nx: true })
          .and_return(true)
        subject.set(lock: 2.seconds).perform_later(argument_id, nil)
      end
    end

    context 'with overridden value' do
      class CustomLockKeyJob < LockableJob
        on_locked nil

        def lock_key
          'custom-lock-key'
        end
      end

      let(:lock_key) { 'custom-lock-key' }

      subject { CustomLockKeyJob }

      it 'matches the overridden value' do
        expect(ActiveJob::Lockable::RedisStore).to receive(:set)
          .with(lock_key, String, { ex: 2, nx: true })
          .and_return(true)
        subject.set(lock: 2.seconds).perform_later(argument_id)
      end
    end
  end
end
