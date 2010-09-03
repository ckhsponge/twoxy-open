
require 'net/http'
require 'uri'
#require 'http_encoding_helper' #for gzip support use response.plain_body
require 'httparty'

class FetchController < ApplicationController
  EXPIRE_FETCH = 1.minutes
  EXPIRE_CONTENT = 15.minutes
  
  def index
    @sources = params[:sources].split("\n").collect{|s| s.strip.gsub(" ","+")} if params[:sources]
  end
  
  #uses Net::HTTP
  def url
    httparty
  end
  
  #uses httparty lib
  def httparty
    serve_cached_data_for_source("HTTPPARTY") do |source|
      response = HTTParty.get(source)
      #puts "reponse #{reponse.class} #{response.methods.sort}"
      #puts response.body
      response.body
    end
  end
  
  protected
  #cache_prepend distinguishes caches
  def serve_cached_data_for_source( cache_prepend = "" )
    source = params[:source]
    unless source
      render :text => "no url specified"
      return
    end
    result = data_cache.fetch("#{cache_prepend}#{source}", :expires_in => EXPIRE_FETCH ) do
      begin
        yield(source)
      rescue Exception => exc
        logger.error exc.to_s
        "not found, please wait #{EXPIRE_FETCH} seconds and try again (#{exc.to_s})"
      end
    end
    headers["Cache-Control"]="max-age=#{EXPIRE_CONTENT}"
    headers["Vary"]="Accept-Encoding"
    render :text => result
  end
    
  def data_cache
    ActiveSupport::Cache::FileStore.new "cache"
  end
end
