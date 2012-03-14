require 'sinatra/base'
require 'soulmate'
require 'rack/contrib'

module Soulmate

  class Server < Sinatra::Base
    
    include Helpers
    
    use Rack::JSONP
    
    before do
      content_type 'application/json', :charset => 'utf-8'
    end
    
    get '/' do
      MultiJson.encode({ :soulmate => Soulmate::Version::STRING, :status   => "ok" })
    end
    
    get '/search' do
      params[:types] = SOULMATES.collect {|t| t.to_s.underscore } if params[:types].nil?

      raise Sinatra::NotFound unless (params[:term] and params[:types] and params[:types].is_a?(Array))
      
      limit = (params[:limit] || 5).to_i
      types = params[:types].map { |t| normalize(t) }
      term  = params[:term]
      
      results = {}
      types.each do |type|
        matcher = Matcher.new(type)
        
        cachekey = "soulmate-usercache:#{current_user.id}:" + type
        klass = type.classify.constantize
        
        if !Soulmate.redis.exists(cachekey) && klass.respond_to?(:soulmate_scope_visibility?) && klass.soulmate_scope_visibility?
          sql = klass.accessible_by(current_ability).select(:id).to_sql
          @ids = klass.connection.select_values(sql)
          @ids = @ids.any? ? @ids : [0]
          
          Soulmate.redis.sadd(cachekey, *@ids)
          Soulmate.redis.expire(cachekey, 10 * 60)
        end
        
        if klass.respond_to?(:soulmate_scope_visibility?) && klass.soulmate_scope_visibility?
          matcher.visible_ids = @ids || Soulmate.redis.smembers(cachekey)
        end
        
        if klass.respond_to?(:soulmate_scoped_ids)
          matcher.scoped_ids = klass.soulmate_scoped_ids(params)
        end
        
        results[type] = matcher.matches_for_term(term, :limit => limit)
      end
      
      MultiJson.encode({
        :term    => params[:term],
        :results => results
      })
    end
    
    not_found do
      content_type 'application/json', :charset => 'utf-8'
      MultiJson.encode({ :error => "not found" })
    end
    
    private
    
    def current_user
      User.find(session["warden.user.user.key"][1].first)
    end
    
    def current_ability
      @current_ability ||= Ability.new(current_user)
    end
    
  end
  
end
