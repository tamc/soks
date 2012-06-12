class Wiki2Html
	
	DEFAULT_SETTINGS = {
		:views_to_copy => ['view','meta','rss'],
		:extension => '.html',
		:destination_dir => '/Users/tamc2/Sites',
		:destination_url => 'http://localhost/~tamc2'
	}
	
	def initialize( wiki, view, settings = {} )
		@settings = DEFAULT_SETTINGS.merge( settings )
		@wiki, @view = wiki, view
		@wiki.watch_for( :page_created, :page_deleted ) { |event, page| new_page( page ) }
		@wiki.watch_for( :page_revised ) { |event, page| page_revised( page ) }
		update_all_pages
	end

	def new_page( page )
		copy_all_views( page.name )
		titleregex = Regexp.new( page.name, Regexp::IGNORECASE )
		@wiki.each { |name, linkedpage | 
			page_revised( linkedpage ) if linkedpage.textile =~ titleregex
		}
	end
	
	def page_revised( page )
		copy_all_views( page.name )
		page.inserted_into.each { |including_page| copy_all_views( including_page.name ) }
	end
	
	def update_all_pages
		@wiki.each { |pagename, page| copy_all_views( pagename) }
	end
	
	def copy_all_views( pagename )
		@settings[:views_to_copy].each { |view| copy_view( pagename, view ) }
	end
	
	def copy_view( pagename, view )
		$stderr.puts "Copying #{pagename} #{view}"
		html =  @view.view( pagename, view )
		update_links html
		destination = "#{@settings[:destination_dir]}/#{view}/#{pagename}#{@settings[:extension]}".downcase
		File.mkpath(File.dirname(destination)) unless File.exists?(File.dirname(destination))
		File.open( destination,'w') {|file| file.puts html}
	end
	
	def update_links( html )
		old_link = /['"]#{$SETTINGS[:url]}\/(.*?)\/(.*?)(\.\w*)?['"]/
		html.gsub!(old_link) do |match|
			if ($1.downcase == 'attachment' || @settings[:views_to_copy].include?( $1.downcase ))
				"'#{@settings[:destination_url]}\/#{$1.downcase}\/#{$2.downcase}#{$3 || @settings[:extension]}'"
			else
				match
			end
		end
		html
	end	
	
end