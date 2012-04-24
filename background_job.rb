# Background Job
#
# For starting a simple Resque background job, given a model ID, the model's class, and an instance method.

module BackgroundJob
  
  @queue = :background_jobs
  
  # Perform the lookup and execute the method.
  def self.perform(id, klass_name, method_name)
    klass = klass_name.constantize
    if obj = klass.find_by_id(id)
      obj.send(method_name)
    end
  end
  
end