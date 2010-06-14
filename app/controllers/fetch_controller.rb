
require 'net/http'
require 'uri'
class FetchController < ApplicationController
  EXPIRE_FETCH = 1.minutes
  EXPIRE_CONTENT = 15.minutes
  
  def index
    @sources = params[:sources].split("\n").collect{|s| s.strip} if params[:sources]
  end
  
  def url
    source = params[:source]
    unless source
      render :text => "no url specified"
      return
    end
    result = data_cache.fetch(source, :expires_in => EXPIRE_FETCH ) do
      begin
        response = fetch_url(source)
        #puts response.body
        response.body
      rescue Exception => exc
        logger.error exc.to_s
        "not found, please wait #{EXPIRE_FETCH} seconds and try again (#{exc.to_s})"
      end
    end
    headers["Cache-Control"]="max-age=#{EXPIRE_CONTENT}"
    headers["Vary"]="Accept-Encoding"
    render :text => result
  end
  
  protected
  def fetch_url(uri_str, limit = 10)
    puts "fetch_url #{uri_str}"
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    url = URI.parse(uri_str)
    request = Net::HTTP::Get.new(url.path)
    #fake the user agent
    #request['User-Agent'] = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3"
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
