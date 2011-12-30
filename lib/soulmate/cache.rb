module Soulmate
  
  class Cache < Struct.new(:key, :ids)
    
    def enqueue!
      warn "Define enqueue! in your initializer to make use of your queue flavor."
      perform!
    end
        
    def perform!
      Soulmate.redis.multi
        ids.each { |id| Soulmate.redis.sadd(key, id) }
      Soulmate.redis.exec
      Soulmate.redis.expire(key, 10 * 60)
    end
    
  end
  
end