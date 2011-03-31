
require 'net/http'
require 'uri'
require 'httparty'
#require 'system_timer'


class FetchController < ApplicationController
  EXPIRE_FETCH = 5.minutes #local file cache expiry
  EXPIRE_CONTENT = 15.minutes #remote cdn and browser client expiry
  TIMEOUT_INTERVAL = 15.seconds
  
  ERROR_PREFIX = "ERROR"
  
  def index
    @sources = params[:sources].split("\n").collect{|s| s.strip.gsub(" ","+")} if params[:sources]
  end
  
  #uses Net::HTTP
  def url
    serve_cached_data_for_source do |source|
      begin
        #SystemTimer.timeout_after(TIMEOUT_INTERVAL + 1) do
        response = HTTParty.get(source, :timeout => TIMEOUT_INTERVAL)
        #puts "reponse #{reponse.class} #{response.methods.sort}"
        #puts response.body
        response.body
        #end
      rescue Exception => exc
        logger.error exc.to_s
        "#{ERROR_PREFIX}: data not found, please wait #{EXPIRE_FETCH} seconds and try again (#{exc.to_s})"
      end
    end
  end
  
  protected
  #cache_prepend distinguishes caches
  def serve_cached_data_for_source
    source = params[:source]
    unless source
      render :text => "no url specified"
      return
    end
    result = data_cache ? data_cache.fetch("#{source}", :expires_in => EXPIRE_FETCH ) { yield(source) } : yield(source)
    headers["Cache-Control"]="public, max-age=#{EXPIRE_CONTENT}"
    headers["Vary"]="Accept-Encoding"
    status = result.starts_with?(ERROR_PREFIX) ? :not_found : :ok #using the beginning text to determine status code is hacky
    render :text => result, :status => status
  end
    
  def data_cache
    return nil #disable cache for use on heroku
    ActiveSupport::Cache::FileStore.new "cache"
  end
end
