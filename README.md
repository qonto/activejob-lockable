![Gem Version](https://badge.fury.io/rb/activejob-lockable.svg) ![CI Status](https://github.com/qonto/activejob-lockable/actions/workflows/tests.yml/badge.svg)

# ActiveJob::Lockable

Gem to make to make jobs lockable. Useful when a job is called N times, but only a single execution is needed.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activejob-lockable'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activejob-lockable

## Configuration

Create an initializer with redis connection:

```ruby
ActiveJob::Lockable.redis = Redis.current # if you have a redis instance

# or
ActiveJob::Lockable.redis = 'redis://localhost:6379/0'
# or
ActiveJob::Lockable.redis = {
  host: '10.0.1.1',
  port: 6380,
  db: 15
}
```

## Usage

```ruby
# job
# nothing to change!
```
```ruby
# code
MyJob.set(lock: 10.seconds).perform_later(id)
```

Now, after the first enqueue (perform_later), a lock will be created and the following enqueues within 10 seconds will be rejected.

### Lock key

A lock key by default:

`job_name_in_downcase:md5(arguments)`

To override the key you can override method `lock_key`:

```ruby
# job
def lock_key
  'my-custom-key'
end
```

### Lock period

You can set a fixed `lock_period`, in that case `.set(lock: N)` will be ignored and the job will always be lockable:

```ruby
# job
def lock_period
  1.day
end
```

### On lock action

When a job is locked and another one is enqueued, you can set up a custom callback that will be called. This is useful if you want to raise exception or be notified:

```ruby
# job
class MyJob < ApplicationJob
  on_locked :raise_if_locked

  def raise_if_locked
    raise 'Job is locked'
  end
end
```

## Dependencies

* [ActiveSupport](https://github.com/rails/rails/tree/master/activesupport)
* [ActibeJob](https://github.com/rails/rails/tree/master/activejob)
* [Redis](https://redis.io/)

## Contributing

Bug reports and pull requests are welcome on GitHub at [qonto/activejob-lockable](https://github.com/qonto/activejob-lockable). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Releasing

To publish a new version to rubygems, update the version in `lib/activejob/lockable/version.rb`, and merge.
