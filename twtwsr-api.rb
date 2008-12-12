#
# $Id: twtwsr-api.rb 13 2008-09-04 12:30:19Z masuda $
#
require 'net/http'

=begin
class twtwsr-api
=end

class TwtwsrApi

   def initialize(user, pass, host)
      super()
      @user = user
      @pass = pass
      @host = host
      @http = Net::HTTP.new(@host)
   end

   def set_user(user)
      @user = user
   end

   def set_pass(pass)
      @pass = pass
   end

   def http_new(host = @host)
      proxy_class = Net::HTTP::Proxy(nil)
      if @use_proxy && @proxy != nil && @proxy != '' && @proxy_port != nil &&  @proxy_port != '' then
         if @use_proxy && @proxy_user != nil && @proxy_user != '' then
            proxy_class = Net::HTTP::Proxy(@proxy, @proxy_port, @proxy_user, @proxy_pass)
         else
            proxy_class = Net::HTTP::Proxy(@proxy, @proxy_port)
         end
      end
      proxy_class.new(host)
   end

   def get(path, head)
      res = nil
      begin
         res = @http.get(path, head)
      rescue Exception => evar
         res = evar
      end
      res
   end

   def get_with_auth(path, head)
      now = Time.now.getgm
      now_str = now.strftime('%Y/%m/%d %H:%M:%S +0000')
      auth = ["#{@user}:#{@pass}"].pack("m").chomp
      head['Authorization'] = "Basic #{auth}"
      get(path, head)
   end

   def post(path, data, head)
      res = nil
      begin
         res = @http.post(path, data, head)
      rescue Exception => evar
         res = evar
      end
      res
   end

   def post_with_auth(path, data, head)
      auth = ["#{@user}:#{@pass}"].pack("m").chomp
      head['Authorization'] = "Basic #{auth}"
      post(path, data, head)
   end

   def update(status)
      path = '/statuses/update.json'
      enc = URI.encode(status, /[^a-zA-Z0-9\'\.\-\*\(\)\_]/n)
      data = 'status=' + enc
      data += '&source=' + PROG_NAME
      head = {'Host' => @host}
      post_with_auth(path, data, head)
   end

  def replies(since = nil)
     path = '/statuses/replies.xml'

     if since
        since.gsub!(' ', '+')
        since.gsub!(',', '%2C')
        path += "?since=#{since}"
     end

     head = {'Host' => @host}
     get_with_auth(path, head)
  end

end

## __END__
