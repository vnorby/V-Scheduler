# V Scheduler
### Schedule tasks to run at X time in the future without any gems or configuration in Rails.

VScheduler is designed to be the simplest solution for scheduling a task to run at a predetermined time in the future. It's not a gem, there's no complicated setup, no god monitoring needed, you just drop 2 files into your existing Resque setup. In order to run V Scheduler, you will need Resque and you will need significant enough load on your application that you can place a function somewhere in it that will be hit often through the day and night.

Example use cases include:

* I want to send a welcome email to a user 5 minutes after they sign up.
* I want to check in 24 hours whether a user has verified their email, and if they haven't, trigger a follow-up.
* Every 3 weeks, I want to destroy posts older than a month.

**Here's how to get started:**

1. Download `v_scheduler.rb` and drop it in the folder where you store other modules. `/app/lib` is a good place for it.
2. Download `background_job.rb` and place it in your `/app/jobs` folder where you store other Resque background jobs.
3. Somewhere in your application that is hit often enough, place `VScheduler.run` For example, to run it on every page load:

```ruby
class ApplicationController < ActionController::Base
  before_filter :run_v_scheduler
  def run_v_scheduler
    VScheduler.run
  end
end
```

**Here's how to schedule tasks:**

This code:

```ruby
VScheduler.schedule(5.minutes, "User", "send_welcome", 1)
```

Will execute the following in 5 minutes:

```ruby
User.find_by_id(1).send_welcome
```

It's that simple!
