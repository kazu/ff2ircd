require "rupircd/server"

module IRCd::ServerHook

  def _hook(src,callback)
    IRCd::IRCServer.__send__(:define_method, :set_ff, Proc.new{|x|
      @ff = x
    })
    orig_method = (src.to_s + "_orig").to_sym
    IRCd::IRCServer.__send__(:alias_method, orig_method, src)

    IRCd::IRCServer.__send__(:define_method, src, Proc.new{|*args|
      begin 
        unless @ff
          p "new ff"
          ff = IRCd::FFConnecter.new
          ff.set_server(self)
          set_ff(ff)
        end
        yield(self,orig_method,*args)
     rescue RuntimeError=>e
       #@ff.debug e.message,e.backtrace
     end
    })
  end 

  def before(src,callback)
    _hook(src,callback){|server,orig_method,*args|
      server.instance_eval{
	@ff.send(callback,*args)
      }
      server.__send__(orig_method,*args)
    }
  end

  def after(src,callback)
    _hook(src,callback){|server,orig_method,*args|
      server.__send__(orig_method,*args)
      server.instance_eval{ 
        @ff.send(callback,*args)
      }
    }
  end
  def hook(src,callback)
    _hook(src,callback){|server,orig_method,*args|
      server.instance_eval{@ff}.send(callback,server,*args){|server|
          server.__send__(orig_method,*args)
      }
    }
  end
end


