# PerActionMw plugin
#
# David A. Black
# January 16, 2009
#
# See README for more information
#

module ActionController

# Module gets included into all mw app classes. If
# they write their own initialize, it will take precedence
# (and can call super if it wants to).
  module RackParentApp
    def initialize(app)
      @app = app
    end
  end

  class Base

  # Class methods, for handling the "white" and "black" lists (:only and
  # :except actions) and the middle command itself. 

    class << self
      attr_accessor :mw_stack
      
      def middles
        @middles ||= []
      end

      def middleware_whitelist
        @middleware_whitelist ||= Hash.new {|h,k| h[k] = [] }
      end
      
      def middleware_blacklist
        @middleware_blacklist ||= Hash.new {|h,k| h[k] = [] }
      end
    
      def middle(app, *options)
        options = options.pop || {}
        middles.push(app)
        Array(options[:only]).each {|action| middleware_whitelist[app] << action.to_sym }
        Array(options[:except]).each {|action| middleware_blacklist[app] << action.to_sym }
      end
    end

    def after_stack
      @after_stack
    end

  # Reports whether a given piece of middleware is usable by the action
  # currently being processed. 
    def can_use_middleware?(mw)
      klass = self.class
      return true if klass.middleware_whitelist[mw].include?(action_name.to_sym)
      return false if klass.middleware_blacklist[mw].include?(action_name.to_sym)
      return true if klass.middleware_whitelist[mw].empty?
    end

    def stack_hash
      self.class.stack_hash
    end

    def self.stack_hash
      @stack_hash ||= {}
    end
    
  # The middleware stack, which will be interposed between the request and
  # the response. 
    def prepare_mw_stack
      stack_hash[action_name] ||= MiddlewareStack.new do |middleware|
        self.class.middles.each do |mw|
          if can_use_middleware?(mw)
            mw.send(:include, RackParentApp)
            middleware.use(mw)
          end
        end
      end
      @app = stack_hash[action_name].build(lambda { |env| _call(env) })
    end

  # At the bottom of the stack, this method does the actual/traditional
  # triggering of the action. 
    def _call(env)
      send(*@send_args)
      response.to_a
    end

# This is not a candidate for alias_method_chain, because it isn't chained.
# It cannot hand off control to the original #process method, which is
# very differently engineered. 
    def process(request, response, method = :perform_action, *arguments) #:nodoc:
      response.request = request
      initialize_template_class(response)
      assign_shortcuts(request, response)
      initialize_current_url
      assign_names
      log_processing

    # This hooks the processing into the middleware stack. 
      prepare_mw_stack
      @send_args = [method, *arguments]
      @app.call(request.env)

    # Content-Length will be restored by response.prepare! later. 
    # It gets in the way here because it's an empty
    # string, instead of not existing. This could use
    # further research (in Rack::Response?). 
      response.headers.delete("Content-Length")
      send_response
    ensure
      process_cleanup
    end
  end
end