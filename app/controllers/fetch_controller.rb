
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
        body = Net::HTTP.get(URI.parse(source))
        puts body
        body
      rescue Exception => exc
        logger.error exc.to_s
        "not found, please wait #{EXPIRE_FETCH} seconds and try again"
      end
    end
    headers["Cache-Control"]="max-age=#{EXPIRE_CONTENT}"
    render :text => result
  end
  
  protected
  def data_cache
    ActiveSupport::Cache::FileStore.new "cache"
  end
end
