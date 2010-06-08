class ActiveSupport::Cache::FileStore
  puts "loaded"
  def read(name, options = nil)
    super
    file_name = real_file_path(name)
    # It is much faster than using begin/rescue with File.mtime
    # with the current MRI (factor of 9)
    return nil unless File.exist?(file_name)
    if (expires = expires_in(options)) > 0 and (Time.now - File.mtime(file_name)) > expires
      return nil
    end
    File.open(file_name, 'rb') { |f| Marshal.load(f) } rescue nil
  end
  
  private
  def expires_in(options)
    (options && options[:expires_in]) || 0
  end
end