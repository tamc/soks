# Extend the model classes to provide view functions
class Page
	def textile( view = nil )
		return "[[#{$MESSAGES[:Create]} #{name} => /edit/#{name} ]]" if empty? 
		content 
	end
end

class ImagePage
  def textile( view )
  	return "[[#{$MESSAGES[:Create]} #{name} => /edit/#{name} ]]" if empty?
  	return content if deleted?
  	"!#{view.file2(content)}!:#{view.url(name)}" 	
  end
end

class AttachmentPage 
  def textile( view )
  	return "[[#{$MESSAGES[:Create]} #{name} => /edit/#{name} ]]" if empty?
  	return content if deleted? 
  	%Q{[[ #{name} => #{view.file2(content)} ]]\n} 	
  end
end

# This module is used to extend each erb page to provide helper methods
module ErbHelper
	
	attr_accessor :name
	attr_accessor :description
	attr_accessor :author_to_email_conversion
	
	def url( name, view = 'view', query = '' )
		return unless name
		"#{root_url}/#{view}/#{url_name_for_page_name(name)}#{query}"
	end
	
	def file( name )
		"#{root_url}/attachment/#{name}"
	end
	
	# Will refactor this out eventually and merge with above
	def file2( name )
		name = name[1..-1] if name[0,1] == '/'
		"#{root_url}/#{name.strip}"
	end
end

# This class records all the links between pages
class Links
	
	attr_reader :links
	
	def initialize
		@links = Hash.new
	end
	
	def links_from( page ) ; return @links[ page ] ; end
	
	def set_links_from( page, linkarray )
		
		page.links_lock.synchronize do 
			page.links_from = @links[ page ] = linkarray.uniq
			set_links_to( page )
		end
		
		page.links_from.each { |linked_page|
			linked_page.links_lock.synchronize do  
				set_links_to( linked_page )
			end 
		}
	end
	
	private
	
	def set_links_to( thispage )
		linksto = Array.new
		@links.each do | pagefrom, pagesto |
			next if pagefrom == thispage
			next if linksto.include? pagefrom
			linksto << pagefrom if pagesto.include? thispage 
		end
		thispage.links_to = linksto.sort
	end
end

class BruteMatch
	
	IGNORE_CASE = true

	def initialize
		@matches = Hash.new
		@titles = Array.new #sorted array for speed 
	end

	def []( title ) @matches[ lower_case(title) ] end
	alias :object_for :[]
	
	def delete( title ) 
		@matches.delete( title )
		update_titles
	end
	
	# Use this to add a string to match and an associated object to return
	# if an object is matched.
	def []=( title, object )
		@matches[lower_case(title)] = object
		update_titles
	end
	
	def match( text, do_not_match = [] )
		do_not_match = do_not_match.map { |title| lower_case(title) }
		@titles.each do |title,regexp,page|
			next if do_not_match.include? title
			text.gsub!( regexp ) { |match| "#{$1}#{yield $2, page}#{$3}" }
		end
		text
	end
	
	private
	
	# The title, a regexp to match for the title, and the page are stored in a sorted array
	def update_titles
		@titles = @matches.keys.sort_by { |title| title.length }.reverse.map do |title|
			[ title, /(^|\W)(#{Regexp.escape( title )})(\W|$)/i, @matches[ title ] ]
		end
	end
	
	def lower_case( text )
	    IGNORE_CASE ? text.downcase : text
	end
end

# This adds some extra match types to (a bodged version of) RedCloth
# 
# Specifically:
# * Inserting other pages
# * Square bracketed wiki links 
# * Automaticlly links anytime the title of another page appears in the text
# * Automatically links things that look like email addresses and urls
class WikiRedCloth < RedCloth
	
	RULES = [:refs_soks_bracketed_link, :refs_textile, :block_textile_table, :block_textile_lists,:block_textile_prefix, :inline_textile_image, :inline_textile_link, :inline_textile_code, :inline_soks, :inline_textile_glyphs, :inline_textile_span, :refs_markdown, :block_markdown_setext, :block_markdown_atx, :block_markdown_rule, :block_markdown_bq, :block_markdown_lists, :inline_markdown_reflink, :inline_markdown_link ]
	
	def initialize( wiki, page, string, hard_breaks = false )
		@wiki, @view, @page = wiki, wiki, page
		@internal_links_from_page = []
		super(insert_sub_strings( string.dup ),[:no_span_caps])
		self.hard_breaks = hard_breaks
	end
	
	def to_html
		super( *RULES ).to_s
	end
		
	def inline_soks( text )
		hide_html_links text
		hide_html_tags text 	
		inline_soks_external_link text
		inline_soks_automatic_link text
		unhide text
		@wiki.links.set_links_from( @page, @internal_links_from_page )
      text
	end

	private
	
	def hide_html_links( text )
		text.gsub!(/<a.*?<\/a.*?>/i) { |m| hide m }
	end

	def hide_html_tags( text )
		text.gsub!(/<.*?>/m) { |m| hide m }
	end 
	
	def unhide( text )
	  hidden.each_with_index do |r, i|
         text.gsub!( / --!!#{ i + 1 }!!-- /, r ) 
      end
	  text
	end

	def hidden
		@hidden ||= []
	end	

	def hide( text )
		hidden << text
		" --!!#{hidden.length}!!-- "
	end

	def insert_sub_strings( text, count = 0 )
	  return text if count > 5 # Stops us getting locked into a cycle if people mess up the insert
	  text.gsub!(/\[\[\s*(insert (.+?))\s*\]\]/i) do |match|
		if @wiki.exists? $1 # So we don't accidentlaly match a page whose name starts 'insert'
	  		match
		else
			inserted_page = @wiki.page( $2 )	
			@internal_links_from_page << inserted_page if @wiki.exists? inserted_page.name
		  	inserted_page.is_inserted_into( @page )
			insert_sub_strings( "#{inserted_page.textile(@view)}\n", count + 1 )
		end 
	  end
	  text
	end		

	def inline_soks_external_link( text )
	    text.gsub!(/http:\/\/\S*\w\/?/i) 				{ |m| link m }
	    text.gsub!(/https:\/\/\S*\w\/?/i) 				{ |m| link m }
	    text.gsub!(/www\.\S*\w\/?/i) 					{ |m| link( "http://#{m}", m) }
	    text.gsub!(/[A-Za-z0-9.-]+?@[A-Za-z0-9.-]*[A-Za-z]/)	{ |m| link( "mailto:#{m}", m) }
	end
		
	def refs_soks_bracketed_link( text )
		text.gsub!(/\[\[\s*(.*?)\s*(|=>\s*(.*?)\s*)\]\]/) do |m| 
     		title, pagename = $1, $3
			pagename ||= title
			case pagename
			
			# http://soks.rubyforge.org/index
			when /^http(s)?:\/\//i 					; link(pagename,title)
			
			# www.soks.org
			when /^www\./i 							; link("http://#{pagename}", title )
			
			# tamc@soks.org
			when /[A-Za-z0-9.]+?@[A-Za-z0-9.]+/ 	; link("mailto:#{pagename}",title)
			
			# /revision/Home page?revision=10
			when %r{^/(\w+)/(.+?)(\?\w+=\w+)$} 
				@internal_links_from_page << @wiki.page($2) if @wiki.exists?($2)
				link( @view.url($2,$1,$3), title, @wiki.exists?($2) ? '':'missing' )
			
			# /edit/a new page	
			when %r{^/(\w+)/(.+)} 
				@internal_links_from_page << @wiki.page($2) if @wiki.exists?($2)
				link( @view.url($2,$1), title, @wiki.exists?($2) ? '':'missing' )
			
			# the name of a page
			else 
				@internal_links_from_page << @wiki.page(pagename) if @wiki.exists? pagename
				link( @view.url( pagename ), title, @wiki.exists?(pagename) ? '':'missing' )
			end
		end
	end
       
  	def inline_soks_automatic_link( text )
		@wiki.rollingmatch.match( text,	[@page.name] ) do |title, page|
			@internal_links_from_page << page
			link( @view.url(page.name), title, 'automatic' )
		end
	end
	
	def link( url, title = url, css_class = '' )
		shelve "<a href='#{url}' class='#{css_class}'>#{title}</a>"
	end
	
end

module PageNameToUrlNameConversion
	
	def setup_page_name_to_url_name_conversion
		@urls_to_pages, @pages_to_urls = {}, {}
		@wiki.each { |name,page| url_name_for_page_name( page.name ) }
		@wiki.watch_attentively_for(:page_created) {|event,page,revision| url_name_for_page_name( page.name )}
		@wiki.watch_attentively_for(:page_title_recapitalized) {|event,page| change_caps_for( page.name )}
	end
	
	# To allow punctuation in page titles and not mess up urls
	def url_name_for_page_name( page_name )
		@pages_to_urls[ page_name.downcase ] || add_url_name_for_page_name( page_name )
	end
	
	def page_name_for_url_name( url_name )
		@urls_to_pages[ url_name.downcase ] || url_name 
	end
	
	def add_url_name_for_page_name( page_name )
		url_name = create_url_name( page_name )
		@pages_to_urls[ page_name.downcase ] = url_name
		@urls_to_pages[ url_name.downcase ] = page_name
		url_name 
	end
	
	def change_caps_for( page_name )
		url_name = @pages_to_urls[ page_name.downcase ].downcase
		@urls_to_pages[ url_name  ] = page_name
	end
	
	# Turns text into a WikiWord by changing the capitalization and then dumping the punctuation
	def create_url_name( page_name )
		url_name = page_name.capitalize.gsub(/(\W+(\w))/) { |m| $1.upcase }.gsub(/\W+/,'')
		url_name = "PunctuationOnlyInTitle" if url_name == ""
		url_name = increment_url_name( url_name ) while @urls_to_pages.has_key? url_name.downcase
		url_name
	end
	
	def increment_url_name( url_name )
		if url_name =~ /(\w+)-(\d+)/
			"#{$1}-#{$2.to_i.succ}"
		else
			url_name+"-2"
		end 
	end
end

class View
	include ErbHelper
	include PageNameToUrlNameConversion

	REDCLOTH_CACHE_NAME = 'redcloth'

	attr_reader :rollingmatch, :links
	attr_accessor :view_folder
	attr_accessor :root_url
	attr_accessor :reload_erb_each_request
	attr_accessor :dont_frame_views
	attr_accessor :redcloth_hard_breaks
	
	def initialize( wiki, root_url, view_folder )
		@wiki, @root_url, @view_folder = wiki, root_url, view_folder
		@rollingmatch, @links = BruteMatch.new, Links.new
		@redcloth_cache = wiki.load_cache(REDCLOTH_CACHE_NAME) || Hash.new
		@erb_cache = Hash.new
		@reload_erb_each_request = false
		@dont_frame_views = []
		@redcloth_hard_breaks = false
		setup_page_name_to_url_name_conversion
		wiki.watch_attentively_for( :page_revised ) { |event,page,revision| refresh_redcloth( page ) }
		wiki.watch_for(:shutdown) { wiki.save_cache(REDCLOTH_CACHE_NAME,@redcloth_cache) }
	end

	def render( pagename, view = 'view', person = 'Anon.', query = {} )
		page = @wiki.page( pagename )
	   	renderedview = redcloth( page )
		content_of_page = html( page.class, view, binding )
		@wiki.notify(:page_viewed, page, view, person)
		if should_frame? view 
			return frame_erb.result(binding)
		else
			return content_of_page
		end
	end
		
	def refresh_redcloth( page )
		$LOG.info "Refreshing #{page}"
		@redcloth_cache[ page.name ] = WikiRedCloth.new( self, page, page.textile(self), redcloth_hard_breaks).to_html
	end
	
	def redcloth( page )
		textile = page.textile(self)
		@redcloth_cache[ page.name ] || refresh_redcloth( page )
	end
	
	def clear_redcloth_cache( page = :all_pages )
		( page == :all_pages ) ? @redcloth_cache.clear : @redcloth_cache.delete( page )
	end
	
	def html( klass, view, _binding )
		@erb_cache.clear if reload_erb_each_request
		( @erb_cache[ path_for( klass, view ) ] ||= ERB.new( IO.readlines( erb_filename( klass, view ) ).join ) ).result( _binding )
	end
  
	def erb_filename( klass, view )
		$LOG.info "Looking for #{path_for( klass, view)}"
		 until File.exists?( path_for( klass, view ) )
		 	if klass.superclass
		   		klass = klass.superclass
		   	else
				$LOG.warn "Not found #{path_for( klass, view)}"
				raise WEBrick::HTTPStatus::NotFound
		   	end
	    end
	    path_for( klass, view )
	end

  	def path_for( klass, view ) "#{view_folder}/#{klass}_#{view.downcase}.rhtml" end
	
	def should_frame?( view )
		not( dont_frame_views.include? view.downcase )
	end
	
	def frame_erb
		@frame_erb = nil if reload_erb_each_request
		@frame_erb ||= load_frame_erb
	end
	
	def load_frame_erb
		if File.exists? "#{view_folder}/frame.rhtml"
			ERB.new( IO.readlines( "#{view_folder}/frame.rhtml" ).join )
		else
			ERB.new( "<%= content_of_page %>" )
		end
	end
	
	def method_missing( method, *args, &block )
		# $LOG.debug "View method missing called for #{method} with #{args.inspect}" 
		@wiki.send( method, *args, &block ) 
  	end
end