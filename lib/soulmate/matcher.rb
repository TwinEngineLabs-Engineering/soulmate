module Soulmate

  class Matcher < Base
    
    attr_accessor :visible_ids, :scoped_ids

    def matches_for_term(term, options = {})
      options = { :limit => 5, :cache => true }.merge(options)
      
      words = normalize(term).split(' ').reject do |w|
        w.size < MIN_COMPLETE or STOP_WORDS.include?(w)
      end.sort

      return [] if words.empty?
      return [] if visible_ids && visible_ids.empty?
      return [] if scoped_ids && scoped_ids.empty?

      cachekey = "#{cachebase}:" + words.join('|')

      if !options[:cache] || !Soulmate.redis.exists(cachekey)
        interkeys = words.map { |w| "#{base}:#{w}" }
        Soulmate.redis.zinterstore(cachekey, interkeys)
        Soulmate.redis.expire(cachekey, 10 * 60) # expire after 10 minutes
      end
      
      ids = if visible_ids || scoped_ids
        Soulmate.redis.zrevrange(cachekey, 0, -1) & (visible_ids.to_a | scoped_ids.to_a)
      else
        Soulmate.redis.zrevrange(cachekey, 0, -1)
      end.first(options[:limit])
      
      if ids.size > 0
        results = Soulmate.redis.hmget(database, *ids)
        results = results.reject{ |r| r.nil? } # handle cached results for ids which have since been deleted
        results.map { |r| MultiJson.decode(r) }
      else
        []
      end
    end
     
  end
  
end