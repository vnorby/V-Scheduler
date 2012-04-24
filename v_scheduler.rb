# V Scheduler 
#
# A module for running a task at a scheduled time without doing anything complicated.
# Using it is simple because it works with your existing Resque setup and will be reloaded
# along with the rest of your Rails environment, without any extra gems. Plus, this is easy
# for you to modify to your heart's content.
#
# Use as follows:
#   - In your ApplicationController, or wherever you want this code to execute periodically,
#     place VScheduler.run.
#   - Use VScheduler.schedule to schedule a method to run on one of your model instances after a certain
#     amount of time, like Vscheduler.schedule(5.minutes, 'User', 'send_welcome', 1).
#   - In your User class, you would have some code like:
#     class User < ActiveRecord::Base
#       def send_welcome
#         UserMailer.welcome_user(self)
#       end
#     end

module VScheduler
  
  # Feel free to change any constant names here in the 0.000001% change they are causing namespace collision.
  
  # The Redis key name we use to acquire a lock.
  LOCK_KEY_NAME = "vscheduler_lock"
  # The Redis key name we use to check whether we want to run scheduled tasks or not.
  TIMER_KEY_NAME = "vscheduler_timer"
  # The Redis set name that we store tasks in.
  SET_NAME = "vscheduler_tasks"
  # The time interval to check tasks. This is the minimum amount of time between tasks executing if your system has enough load.
  TIME_INTERVAL_IN_SECONDS = 1
  # Most people have their Redis connection in a REDIS constant. If you don't, feel free to change.
  REDIS_CONNECTION = REDIS
  
  class << self
    
    # This class method should be placed somewhere in your code where it will be
    # run many times per minute or hour, depending on your needs. Note the use of
    # setnx, which should prevent multiple calls to VScheduler.run from being
    # duplicated. It is effectively being used as a lock.
    def run
      current_timestamp = Time.now.to_i
      time_key = REDIS_CONNECTION.get(TIMER_KEY_NAME)
      REDIS_CONNECTION.set(TIMER_KEY_NAME, current_timestamp) if time_key.nil?
      if time_key && time_key.to_i < current_timestamp - TIME_INTERVAL_IN_SECONDS
        REDIS_CONNECTION.set(TIMER_KEY_NAME, current_timestamp)
        if REDIS_CONNECTION.setnx(LOCK_KEY_NAME, current_timestamp)
          VScheduler.execute_scheduled_tasks(current_timestamp)
          REDIS_CONNECTION.del(LOCK_KEY_NAME)
        end
      end
    end
    
    # Using zrangebyscore, we look for any tasks in the queue that are meant to be
    # run before the last timestamp, execute them (which means placing them into Resque
    # to be run when they come up in your Resque queue), and then remove them from the set.
    def execute_scheduled_tasks(current_timestamp)
      set = REDIS_CONNECTION.zrangebyscore(SET_NAME, 0, current_timestamp)
      set.each { |key|
        VScheduler.execute(key)
        REDIS_CONNECTION.zrem(SET_NAME, key)
      }
    end
    
    # Use this to schedule a task to be run on an instance method.
    # For example, you can schedule the "send_welcome" User method to run
    # on a User with ID 123 in 5 minutes like:
    #   VScheduler.schedule(5.minutes, "User", "send_welcome", 123)
    # Behind this scenes in BackgroundJob when it's ready to be executed, this will do the following:
    #   User.find_by_id(123).send_welcome
    def schedule(for_time, klass, method_name, id)
      timestamp = Time.now + for_time
      key = "#{timestamp.to_i}.#{klass}.#{method_name}.#{id}"
      REDIS_CONNECTION.zadd(SET_NAME, timestamp.to_i, key)
    end
    
    # Place the scheduled task into the Resque Queue using BackgroundJob.
    def execute(key)
      parts = key.split(".")
      timestamp = parts[0]
      klass = parts[1]
      method_name = parts[2]
      id = parts[3]
      Resque.enqueue(BackgroundJob, id, klass, method_name)
    end
    
  end
  
end