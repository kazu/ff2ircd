=begin
= FFConnecter -- FriendFeed Connecter for rupircd

  Copyright (c) 2009 Kazuhisa TAKEI <kazuhisa@gmail.com>

  You can redistribute it and/or modify it under the same term as Ruby.

=end

require "rubygems"
require "friendfeed"
require "ff2"
require "pp"
require "rupircd/user"
require "thread"
require "hpricot"

module IRCd
class FFConnecter
  attr_reader :users
  def initialize(user,remotekey,debug)
    @ff = FriendFeed::Client.new.api2_login(user,remotekey)
    @users = {}
    @user = user
    @channels = {}
    @queue = Queue.new
    @feed2list = {}
    @debug = debug
  end

  def debug(*args)
    STDERR.puts "D:" + args.collect{|x|
      if x.class == String
        x
      else
        x.inspect
      end
    }.join("\n") if @debug
  end

  def set_user(user,socket)
    @user = User.new(user, "~"+user,"friendfeed.com",user,socket,user)
  end

  def recieve_nick(opt)
    return true if @th
    set_server(opt[:ircd])
    @user = opt[:user]
    start
  end

  def set_server(ircd)
    @server = ircd
  end
 
  def join(chname)
    return nil unless @lists.include?(chname)
    
  end

  def lists
    return @list if @list
    feedlist = @ff.feedlist2
    @lists = feedlist["sections"].collect{|x|
      x["feeds"].collect{|feed| 
        next if feed["id"]=~/filter|summary/
        feed["id"]  if feed["id"]=~/home|list/
      }
    }.flatten.compact
    @lists
  end

  def irch(name)
    "#" + name
  end
  def set_channels
    @lists ||= lists
    @lists.each{|list|
      set_channel(irch(list),Channel.new(@server,@user,irch(list)))
      @server.handle_reply(@user,@server.channel(irch(list)).join(@user,nil))
      begin
        add_users(list)
      rescue=>e
        STDERR.puts "E: cannot add user to " + list
        raise e
      end
    } 
  end

  def add_users(list)
    uname = nil
    feeds = @ff.feedinfo2(list)["feeds"]
    feeds ||= @ff.feedinfo2(list)["subscribers"]
    feeds.each{|feed|
      uname = feed["id"]
      nick = feed["name"].gsub(/ /,'_')
      # if own, skip
      next if @user.nick == uname
      @feed2list[uname] ||= []
      @feed2list[uname] << list

      user = User.new(nick, "~"+uname,"friendfeed.com",uname,nil,uname)
      @users[uname] = user
      rpl = @server.channel(irch(list)).join(user,nil)
      @server.handle_reply(user,rpl)
    }
  end
 
  def set_channel(chname,ch)
    @server.set_channel(chname,ch)
    @channels[chname.downcase] = ch
  end

  def start
    set_channels
    puts "fin"
    Thread.abort_on_exception = true
    @th = Thread.start do
      @entries = Queue.new

      @ff.feeds_of_friends(@user)["entries"].each{|entry|
        @entries.push entry
      }

      @cursor = @ff.updates(@user, "timeout"=>"1")["realtime"]["cursor"] 

      loop do
        debug "loop start"
        entries = @ff.updates(@user, "cursor"=>@cursor, "timeout"=>"20")
        @cursor = entries["realtime"]["cursor"]

        entries["entries"].each{|entry| @entries.push entry }

        while !(@entries.empty?) do
          entry = @entries.pop
          next unless entry["from"]

          id = entry["from"]["id"]
          debug entry["body"]
          msg = ircbody(entry)

          debug "privmsg: " + entry["from"]["name"] , msg 

          @feed2list[id].each{|chname|
            @server.handle_reply(
              @users[id],
              @server.channel(irch(chname)).privmsg(@users[id],msg )
            )
          } if @feed2list[id]
        end
      end
    end
    sleep 3
  end
 
  def ircbody(entry)
    doc = Hpricot(entry["body"])
    (doc/:a).map{|elm|
      case elm[:href]
      when /twitter/
        elm.swap(elm.inner_html)
      else
        elm.swap(elm[:href])
      end
    }
    doc.to_s
  rescue=>e
    STDERR.puts e.message
    STDERR.puts e.backtrace
    raise e
  end
  
end
end
