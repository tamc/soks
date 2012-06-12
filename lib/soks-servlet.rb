#!/usr/local/bin/ruby
require 'authenticators'
require 'yaml'

class ServletSettings
	
	attr_accessor :view_controller, :wiki
	attr_accessor :home_page
	attr_accessor :default_view
	attr_accessor :upload_directory
	attr_accessor :authenticators
	attr_accessor :static_file_directories 
	attr_accessor :force_no_cache
	attr_accessor :content_types
	attr_accessor :wiki_directory
	
	def initialize( wiki, view_controller )
		@wiki, @view_controller = wiki, view_controller
		@home_page = 'Home Page'
		@default_view = 'view'
		@authenticators = []
		@static_file_directories = {}
		@content_types = {}
		@force_no_cache = false
	end
	
	def url
		@view_controller.root_url
	end
	
	def page_name_for_url_name( url_name )
		@view_controller.page_name_for_url_name( url_name )
	end
	
	def url_name_for_page_name( page_name )
		@view_controller.url_name_for_page_name( page_name )
	end
end

class WikiServlet < WEBrick::HTTPServlet::AbstractServlet
	
	attr_accessor :server, :settings
	
	def initialize( server, servlet_settings )
		@server, @settings = server, servlet_settings
	end
		
	def service( request, response )
		case request.path_info
		
		# Pass some requests directly to static files
		when '/robots.txt', '/favicon.ico'; serveStaticFile( request, response, request.path[1..-1], 'Attachment' )
		
		# If request of the form /verb/pagename then do it
		when /\/(\w+?)\/(.+)/; wiki_service( request, response, $1.capitalize, $2 )
	 	
	 	# If request of the form /pagename then redirect to /view/pagename
		when /\/(.+)/	; response.set_redirect( WEBrick::HTTPStatus::Found, "#{settings.url}/#{settings.default_view}/#{$1}" )
		
		# If request of the form / then redirect to /view/home%20page
		when "/"		; redirect( response, settings.home_page, settings.default_view )

		end
	end
	
	def wiki_service( request, response, verb, url_name )
		authenticate request, response
		make_username_valid( request )
		if settings.static_file_directories.include? verb
			serveStaticFile( request, response, url_name, verb )	
		elsif self.respond_to?( "do#{verb}" )
			self.send( "do#{verb}", request, response,settings.page_name_for_url_name(url_name), request.user )
			set_cache_settings(response)
		else
			renderView( request, response, settings.page_name_for_url_name(url_name), verb, request.user )
			set_cache_settings(response)
		end
	end
	
	def authenticate( request, response )
		settings.authenticators.each do |path_regex,authenticator|
			if request.path_info.downcase =~ path_regex
				authenticator.authenticate( request, response )
				break
			end
		end
	end
	
	# A special redirect to allow WikiLink style urls
	# Not sure if used by anyone, so may delete
	def doWiki( request, response, pagename, person )
		redirect( response, pagename.gsub(/([a-z])([A-Z])/,'\1 \2') )
	end
	
	# This passes any requests for static files onto a FileHandler
	def serveStaticFile( request, response, url_name, view )
		request.script_name = view
	  	request.path_info = "/#{url_name}"
		WEBrick::HTTPServlet::FileHandler.get_instance(@server, settings.static_file_directories[view], true).service(request, response)
	end
	
	# This passes any rendering of the page onto the view class
	def renderView( request, response, pagename, view, person )
		response.body = view_controller.render( pagename, view, person, request.query )
		response['Content-Type'] = settings.content_types[view] || 'text/html'
	end

	# All the following methods change the wiki, then redirect
	
	def doSave( request, response, pagename, person )
		pagename = move_page_as_required( request, response, pagename, person )
		content = request.query["content"].to_s.gsub(/\r\n/,"\n")
		wiki.revise( pagename, content, person ) if content
		redirect( response, pagename )
	end
	
	def doRollback( request, response, pagename, person )
		if request.query['revision']
			wiki.rollback( pagename, request.query['revision'].to_i, person )
		end
		redirect( response, pagename )
	end
	
	def doDelete( request, response, pagename, person )
		wiki.delete( pagename, person )
		redirect( response, pagename )
	end
	
	def doUpload( request, response, pagename, person )
		pagename = move_page_as_required( request, response, pagename, person )
		unless request.query['file'] == ""
			filename = upload_file_data( request.query['file'] )	
			wiki.revise( pagename, filename, person )
		end 
		redirect( response, pagename )
	end

	private
	
	def redirect( response, pagename, verb = settings.default_view )
		response.set_redirect( WEBrick::HTTPStatus::Found, "#{settings.url}/#{verb}/#{settings.url_name_for_page_name(pagename)}" )
	end
	
	# Moves a page if there is a newtitle in the query
	# If the original page had 'type a title' in its tile, then it is assumed to be a template
	# and therefore is not moved.
	def move_page_as_required( request, response, pagename, person )
		new_pagename = "#{request.query["titleprefix"]}#{request.query["newtitle"]}"
		return new_pagename if pagename =~ /#{$MESSAGES[:Type_a_title_here]}/io 
		return pagename if new_pagename == pagename
		wiki.move( pagename, new_pagename, person )
		new_pagename
	end
		
	def upload_file_data( upload_data, destination = settings.upload_directory  )
		return "Uploads prohibited" unless destination
		path = settings.static_file_directories[ destination ]
		filename = File.unique_filename( path , upload_data.filename )
		File.open( File.join( path, filename ), 'wb' ) { |file| upload_data.list.each { |data| file << data } }
		"/#{destination}/#{filename}"
	end
	
	# Make sure the username doesn't start with Automatic
	def make_username_valid( request )
		request.user = "User: #{request.user}" if request.user =~ /^Automatic/i
	end
	
	def set_cache_settings(response)
		return unless @settings.force_no_cache		
		response['Cache-control'] ||= 'no-cache'
		response['Pragma'] ||= 'no-cache'
	end
	
	def wiki; @settings.wiki end
	def view_controller; @settings.view_controller end
	
end