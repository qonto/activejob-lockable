require 'bundler/setup'
require 'activejob/lockable'
require 'active_job'
require 'pry'
require 'fakeredis'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    ActiveJob::Base.logger.level = :warn
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Lockable.redis = FakeRedis::Redis.new
  end

  config.around(:each) do |spec|
    ActiveJob::Base.queue_adapter.enqueued_jobs = []
    ActiveJob::Base.queue_adapter.performed_jobs = []
    spec.run
  end
end
