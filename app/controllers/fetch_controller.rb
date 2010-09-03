
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
    serve_cached_data_for_source do |source|
        response = fetch_url(source)
        #puts response.body
        response.body
    end
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
  
  def fetch_url(uri_str, limit = 10)
    puts "fetch_url #{uri_str}"
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    url = URI.parse(uri_str)
    request = Net::HTTP::Get.new(url.path)
    #fake the user agent
#    request['User-Agent'] = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3"
#    request['Accept'] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
#    request['Accept-Charset'] = "ISO-8859-1,utf-8;q=0.7,*;q=0.7"
#    request['Host'] = "www.google.com"
#    request['Accept-Language'] = "en-us,en;q=0.5"
#    request['Accept-Encoding'] = "gzip,deflate"
#    request['Keep-Alive'] = "115"
#    request['Connection'] = "keep-alive"
#    puts request.to_hash.inspect
    response = Net::HTTP.start(url.host, url.port) {|http|
      http.request(request)
    }
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then fetch_url(response['location'], limit - 1)
    else
      raise "http error #{response.code}-#{response.message}"
    end
  end
    
  def data_cache
    ActiveSupport::Cache::FileStore.new "cache"
  end
end
