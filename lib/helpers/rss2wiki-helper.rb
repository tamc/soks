require 'rss/1.0'
require 'rss/2.0'
require 'open-uri'

class RSS2WikiHelper

	DEFAULT_SETTINGS = {
		:url => 'http://localhost:8000/rss/recent%20changes%20to%20this%20site',
		:pagename => nil, # If nil, uses channel title,
		:update_on_event => :hour,
		:author => 'AutomaticRSS2Wiki',
	}
	
	def initialize( wiki, settings = {} )
		@settings = DEFAULT_SETTINGS.merge( settings )
		@wiki = wiki
		update_rss
		update_wiki
		@wiki.watch_for(@settings[:update_on_event]) do 
			update_rss
			update_wiki
		end
	end
	
	def update_wiki
		@wiki.revise( @settings[:pagename] || @rss.channel.title, render, @rss.items.first.respond_to?('author') ? @rss.items.first.author : "AutomaticRSS" )
	end

	def render
		content = "h1. #{@rss.channel.title}\n\n"
		@rss.items.each do |item| 
			content << "# [[ #{escape(item.title)} => #{item.link} ]]\n"
		end
		content
	end

	def update_rss
		$LOG.info "Updating feed"
		open(@settings[:url]) do |http| 
			@rss = RSS::Parser.parse( http.read , false) 
		end
	end
	
	def escape( string )
		string.tr('[]=>','')
	end
end