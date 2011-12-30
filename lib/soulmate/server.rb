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
        
        if current_user
          cachekey = "soulmate-usercache:#{current_user.id}:" + type
          
          if !Soulmate.redis.exists(cachekey)
            klass = type.classify.constantize
            sql = klass.accessible_by(current_ability).select(:id).to_sql
            @ids = klass.connection.select_values(sql)
            
            Soulmate::Cache.new(cachekey, @ids).enqueue!
          end

          matcher.visible_ids = @ids || Soulmate.redis.smembers(cachekey)
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
      @current_ability ||= DefaultAbility.new(current_user)
    end
    
  end
end
