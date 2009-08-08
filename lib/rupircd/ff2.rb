=begin
= ff2.rb -- ruby-friendfeed v2 api extention

  Copyright (c) 2009 Kazuhisa TAKEI

  You can redistribute it and/or modify it under the same term as Ruby.
=end



require "friendfeed"

module FriendFeed

  # Client library for FriendFeed API.
  class Client
    ROOT_URI2 = URI.parse("http://friendfeed-api.com/v2/")
    API2_URI = ROOT_URI2

    def call_api2(path, get_parameters = nil, 
		  post_parameters = nil, raw = false)

      api_agent = get_api_agent()

      uri = API2_URI + path
      if get_parameters
        uri.query = get_parameters.map { |key, value|
          if array = Array.try_convert(value)
            value = array.join(',')
          end
          URI.encode(key) + "=" + URI.encode(value)
        }.join('&')
      end

      if post_parameters
        body = api_agent.post(uri, post_parameters).body
      else
        body = api_agent.get_file(uri)
      end

      if raw
        body
      else
        JSON.parse(body)
      end
     end

    def validate2
      call_api2('validate')
    end

     def api2_login(nickname, remote_key)
      @nickname = nickname
      @remote_key = remote_key
      @api_agent = get_api_agent()
      @api_agent.auth(@nickname, @remote_key)
      validate2
      self
    end
    def get_list_entries2(nickname)
      require_api_login
      call_api2('feedlist') #/%s' % URI.encode(nickname))['entries']
    end
    
    def feedlist2
      require_api_login
      call_api2('feedlist')
    end
 
    def feedinfo2(feed)
      require_api_login
      call_api2("feedinfo/" + feed)
    end

    def feeds_of_friends(user)
      require_api_login
      call_api2(["feed", user, "friends"].join("/"))
    end

    def updates(user, opt={})
      require_api_login
      call_api2(["updates/feed", user, "friends"].join("/"), opt )
    end

  end
end

