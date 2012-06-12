require 'webrick/config'
require 'webrick/httpstatus'
require 'webrick/httpauth/authenticator'
require 'base64'

module WEBrick
  module HTTPAuth
		
		module SoksUserCookie

			def username_from_cookie(request)
				cookie = request.cookies.find { |cookie| cookie.name == 'username' }
				return cookie.value if cookie
				return nil
			end		   

			def add_cookie(request,response)
				cookie = WEBrick::Cookie.new( 'username', request.user )
				cookie.path = '/'
				cookie.expires = Time.now + ( 60 * 60 * 24 * 180 ) # Expires in 180 days
				response.cookies << cookie
			end
			
		end
		
		class NoAuthenticationRequired
			include SoksUserCookie
			
			def authenticate(req, res)
				req.user = username_from_cookie(req) || req.meta_vars["HTTP_X_FORWARDED_FOR"] || req.meta_vars["REMOTE_ADDR"]
			end
			

		end
		
		class NotPermitted
			
			def authenticate(req, res)
				raise WEBrick::HTTPStatus::Unauthorized
			end
				
		end
	
		class AskForUserName
			include WEBrick::HTTPAuth::Authenticator
			include SoksUserCookie
			
			AuthScheme = "Basic"
	
			def initialize( realm = "editing" )
				config = { :UserDB => "nodb" , :Realm => realm }
		      	check_init(config)
				@config = Config::BasicAuth.dup.update(config)
		   end

		   def authenticate(req, res)
		     unless basic_credentials = check_scheme(req)
		       challenge(req, res)
		     end
		     userid, password = Base64.decode64(basic_credentials).split(":", 2) 
		     if userid.empty?
		       error("user id was not given.")
		       challenge(req, res)
		     end
		     info("%s: authentication succeeded.", userid)
		     req.user = userid
		     add_cookie(req,res)
		     userid
		   end

		   def challenge(req, res)
		     res[@response_field] = "#{@auth_scheme} realm=\"#{@realm}\""
		     raise @auth_exception
		   end

		end
		
    class SiteWidePassword
      include Authenticator
	  include SoksUserCookie

      AuthScheme = "Basic"

      attr_reader :realm, :userdb, :logger

      def initialize( password = "", realm = "editing" )
  			config = { :UserDB => "nodb" , :Realm => realm }
		   check_init(config)
			@config = Config::BasicAuth.dup.update(config)
			@password = password
      end

      def authenticate(req, res)
        unless basic_credentials = check_scheme(req)
          challenge(req, res)
        end
        userid, password = Base64.decode64(basic_credentials).split(":", 2) 
        password ||= ""
        if userid.empty?
          error("user id was not given.")
          challenge(req, res)
        end
 
        if password != @password
          error("%s: password unmatch.", userid)
          challenge(req, res)
        end
        info("%s: authentication succeeded.", userid)
        req.user = userid
       	add_cookie(req,res)
		userid
      end

      def challenge(req, res)
        res[@response_field] = "#{@auth_scheme} realm=\"#{@realm}\""
        raise @auth_exception
      end
    end

	end
end
