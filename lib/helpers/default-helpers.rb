require 'soks'
require 'net/smtp'

class AutomaticUpdateCrossLinks

	def initialize( wiki, view, banned_titles = [] )
		@wiki, @view, @banned_titles = wiki, view, banned_titles
		@wiki.watch_for( :page_created ) { |event, page| new_page( page ) }
		@wiki.watch_for( :page_deleted ) { |event, page| delete_page( page ) }
		@wiki.watch_for( :page_revised ) { |event, page| page_revised( page ) }
		update_all_pages
	end

	def new_page( page )
		return if title_banned? page.name
		@view.rollingmatch[ page.name ] = page 
		titleregex = Regexp.new( Regexp.escape(page.name), Regexp::IGNORECASE )
		# Refresh any page that might mention the title of the new page
		@wiki.each do |name, linkedpage |
			next if linkedpage.is_a? UploadPage
			next unless linkedpage.textile =~ titleregex
			@view.refresh_redcloth( linkedpage )
			# Pages can be inserted into other pages, so need to refresh those as well
			linkedpage.inserted_into.each { |insert| @view.refresh_redcloth( insert ) }
		end
	end
	
	def delete_page( page )
		@view.rollingmatch.delete( page.name )
		page.links_to.each { |linkedpage| @view.refresh_redcloth( linkedpage ) }
	end
	
	def page_revised( page )
		page.inserted_into.each { |including_page| @view.refresh_redcloth( including_page ) }
	end
	
	def update_all_pages
		@wiki.each do |pagename, page| 
			@view.rollingmatch[ page.name ] = page unless title_banned?( page.name )
			@view.links.links[ page ] = page.links_from
		end
		# Not needed now, because notife d
		#@wiki.each do |pagename, page| 
		#	@view.redcloth( page )
		#end
	end
	
	def title_banned?( title )
		@banned_titles.include? title
	end	
end

class AutomaticSummary
	
	DEFAULT_SETTINGS = {
		:max_pages_to_show => nil,
		:description => 'This summary was created automatically',
		:author => 'AutomaticSummary',
		:lines_to_include => 10,
		:sort_pages_by => :created_on, # Could be :revised_on or :score or :name or :name_for_index, or :author
		:reverse_sort => false,
		:remove_deleted_pages => true, # If false will keep references to deleted pages
		:summarise_revisions => false, # If true will list revisions rather than pages
		:merge_revisions_within => false, # If set to a number, repeats with the same author within that many seconds will be merged
	}

	attr_reader :name, :settings, :summary, :wiki, :decision

	def initialize( wiki, name, settings = {}, &decision )
		@wiki, @name, @decision = wiki, name, decision
		@settings = DEFAULT_SETTINGS.merge( settings )
		@summary = FiniteUniqueList.new( @settings[:max_pages_to_show], @settings[:reverse_sort], @settings[:sort_pages_by] )
		add_existing_pages
		start_watching wiki
	end
	
	def start_watching( wiki )
		wiki.watch_for( :page_revised ) do |event,page,revision|
			thing = settings[:summarise_revisions ] ? revision : page
			summary.include?( thing ) ? confirm_old(thing) : check_new(thing)
		end
	end
	
	def confirm_old(thing)
		summary.remove(thing) unless summarise?( thing )
		render_summary_page
	end
	
	def check_new(thing)
		return unless summarise? thing
		remove_previous_revisions thing 
		summary.add thing  
		render_summary_page
	end
	
	def summarise?( thing )
		return false if thing.name == name
		return false if settings[:remove_deleted_pages] && thing.deleted?
		decision.call( thing )
	end
	
	def add_existing_pages
		if settings[:summarise_revisions]
			scan_revisions_allready_in_wiki
		else	
			scan_pages_allready_in_wiki
		end
	end
	
	def scan_pages_allready_in_wiki		
		wiki.each( settings[:remove_deleted_pages] ) do |name,page| 
			next unless summarise?(page)
			summary.add(page)
		end
		render_summary_page
	end
	
	def scan_revisions_allready_in_wiki
		wiki.each( settings[:remove_deleted_pages] ) do |name,page|
			page.revisions.each do |revision| 
				next unless summarise? revision
				remove_previous_revisions( revision )
				summary.add revision
			end
		end
		render_summary_page
	end
	
	def remove_previous_revisions( revision )
		return unless settings[:summarise_revisions]
		return unless settings[:merge_revisions_within]
		revision.number.downto(0) do |previous_number|
			previous_revision = revision.revisions.at( previous_number )
			break unless previous_revision.author == revision.author
			break unless (revision.revised_on - previous_revision.revised_on) < settings[:merge_revisions_within]
			summary.remove( previous_revision )
		end
	end
	
	# These methods relate to how the summary is shown.
	
	def render_summary_page
		wiki.page( name ).content =~ /(.*?<automaticsummary.*?>).*?(<\/automaticsummary>.*)/mi
		wiki.revise( name, ($1 || new_top) + "\n\n" + render_summary + "\n\n" + ($2 || new_tail), @settings[:author] )
	end
	
	def render_summary
		return "No pages found to summarise" if @summary.empty?
		summary.map { |page| render_summary_of_page(page)  }.to_s
	end
	
	def render_summary_of_page( page )
		page.is_inserted_into(wiki.page( name ))
		content = 	"<div class='subpage'>"
		content << 	"[[ #{page.name} ]]<br />\n\n"
		if page.is_a? UploadPage
			content << "[[ insert #{page.name} ]]"
		else
			content << page.content.first_lines( settings[:lines_to_include] ).close_unmatched_html
		end
		content << "\n\np(more). [[(more) => #{page.name}]]\n\n</div>\n"
	end

	def new_top
		(wiki.page(name).empty? ? "" : "#{wiki.page(name).content}\n\n" ) +
"h2. #{name}

p{font-size: x-small;}. #{@settings[:description]}

<automaticsummary warning='DO NOT EDIT between these automatic summary tags, anything you write may be overwritten without warning'>
"	
	end
	
	def new_tail
		"</automaticsummary>"
	end
	

end

class AutomaticList < AutomaticSummary
	
	def render_summary
		summary.map { |page| render_list_item(page) }.to_s
	end
	
	def render_list_item( page )
		"* [[ #{page.name} ]]\n"
	end
	
end

class AutomaticDetailedList < AutomaticList
	
	def render_list_item( page )
		"* [[ #{page.name} ]] revised on #{page.revised_on.strftime('%Y %b %d %H:%M')} by #{page.author}\n"
	end

end

class AutomaticRecentChanges < AutomaticSummary
	
	def initialize( wiki, changes = 200, pagename = "Recent changes to this site", author = "AutomaticRecentChanges", exclude_automatic_helpers = true, merge_revisions_within = 60*60*12 )
		super( wiki, pagename, 	:summarise_revisions => true,
								:max_pages_to_show => changes,
							 	:author => author,
								:sort_pages_by => :revised_on,
								:event => :page_revised,
								:reverse_sort => true,
								:remove_deleted_pages => false,
								:merge_revisions_within => merge_revisions_within ) do |revision|
									exclude_automatic_helpers ? revision.author !~ /^Automatic/i : true
								end
		wiki.watch_for( :day ) {  render_summary_page }		
	end
	
	def render_summary
		content = "<div class='recentchanges'>\n\nh2. Today\n\n"
		previous_time = Time.now
		@summary.each do |revision| 
			unless revision.revised_on.same_day?( previous_time )
				content << "\nh2. #{revision.revised_on.relative_day}\n\n"
				previous_time = revision.revised_on
			end
			content << "* #{revision.revised_on.strftime('%H:%M')} - [[#{revision.name}]] revised by #{revision.author} ([[changes => /revision/#{revision.name}?time=#{revision.created_on.to_i}]])\n"	
		end
		content << "\n\n</div>"
	end
	
end

class AutomaticOnePageIndex
	
	def initialize( wiki, pagename = "Site Index", author = "AutomaticIndex"  )
		AutomaticList.new( wiki, pagename, :author => author, :sort_pages_by => :name_for_index ) do |page|
			page.name !~ /#{Regexp.escape(pagename)}/io
		end
	end	
	
end

class AutomaticMultiPageIndex
 	
	def initialize( wiki, pageroot = "Site Index", author = "AutomaticIndex"  )
 		('A'..'Z').each do |letter|
 			AutomaticList.new( wiki, "#{pageroot} #{letter}.", :author => author, :sort_pages_by => :name_for_index ) do |page|
 				if page.name =~ /^#{Regexp.escape(pageroot)} ([a-z]|Other)\./i
 					false
 				else
 					page.name =~ /^#{letter}.*/i
 				end
 			end
 		end
 	
 		AutomaticList.new( wiki, "#{pageroot} Other.", :author => author, :sort_pages_by => :name_for_index ) do |page|
 			if page.name =~ /^#{Regexp.escape(pageroot)} ([a-z]|Other)\./i
 				false
 			else
 				page.name =~  /^[^A-Za-z].*/i
 			end
 		end
 	
 		AutomaticList.new( wiki, pageroot, :author => author, :sort_pages_by => :name_for_index ) do |page|
 			page.name =~ /^#{Regexp.escape(pageroot)} ([a-z]|Other)\./i
 		end
 	end	
 end
 
class AutomaticCalendar
	
	attr_reader :month_pagename, :day_pagename
	
	def initialize( wiki, month_pagename = '%Y %b', day_pagename = '%Y %b %d', author = "AutomaticCalendar" )
		@wiki, @month_pagename, @day_pagename, @author = wiki, month_pagename, day_pagename, author
		render_coming_year
		@wiki.watch_for(:month) { render_coming_year }
	end
	
	def render_coming_year
		Time.now.month.upto( Time.now.month+12 ) { |m| render_month( m ) }
	end
	
	def render_month( month )
		@wiki.revise( month_pagename( month  ), calendar_for( month ) , @author ) unless @wiki.exists?( month_pagename( month ) )
	end
	
	def calendar_for( month )
		content = "<div class='calendar'>\n\n"
		content << "|_. Su |_. Mo |_. Tu |_. We |_. Th |_. Fr |_. Sa |\n"
		1.upto( time_for( month, 1 ).wday ) { content << "| . " }
		day = nil
		1.upto( 31 ) do |day_no|
			day = time_for( month, day_no )
			break if day.month > month
			content << "| [[ #{day_no} => #{day_pagename( day )} ]] "
			content << "|\n" if day.wday == 6
		end
		day.wday.upto( 5 ) { content << "| . " }
		content << "|\n"
		content << "\n\n#{month_pagename( month-1 )} #{month_pagename( month+1 )} \n"	
		content << "\n</div>"	
	end
	
	def time_for( month, day = 1 )
		year = Time.now.year
		if month > 12
			year +=1
			month -= 12
		elsif month < 1
			year -= 1
			month = month + 12
		end
		if day > 31
			month += 1
			day -= 31
		end
		Time.local( year, month, day, 8, 0 )
	end
	
	def month_pagename( month = Time.now.month ) time_for( month ).strftime(@month_pagename) end
	
	def day_pagename( date = Time.now ) date.strftime(@day_pagename) end
end

class AutomaticUpcomingEvents
	
	def initialize( wiki, calendar, days_passed = 0, days_future = 7, pagename = 'Upcoming Events', author = "AutomaticUpcomingEvents" )
		@wiki, @calendar, @days_passed, @days__future, @pagename, @author = wiki, calendar, days_passed, days_future, pagename, author
		@wiki.watch_for( :page_revised ) { |event, page| page_revised( page ) }
		@wiki.watch_for( :day ) { render_upcoming_events }
	end

	def page_revised( page )
		render_upcoming_events if page.name =~ /^\d\d\d\d ... \d\d/
	end
	
	def render_upcoming_events
		content = "<div class='upcomingevents'>\n\n"
		Time.now.day.upto( Time.now.day+7 ) do |day|
			time =  @calendar.time_for( Time.now.month, day )
			content << "| [[ #{time.relative_day} => #{@calendar.day_pagename( time )} ]] |"
			content << (@wiki.exists?( @calendar.day_pagename(time) ) ? render_event( @calendar.day_pagename( time ) ) : "&nbsp; |\n")	
		end
		content << "\n\np(more). [[(more) => #{@calendar.month_pagename}]]\n\n"
		content << "\n</div>\n"
		@wiki.revise( "Upcoming Events", content , "AutomaticCalendar" ) 
	end
	
	def render_event( name )
		page = @wiki.page( name )
		headings = page.textile.select { |line| line =~ /^h\d\./ }
		headings = headings.map { |heading| heading.to_s[4..-1].strip }
		headings = [ page.textile.first_lines(1) ] if headings.empty?
		content = " [[ #{headings.shift} => #{page.name} ]] |\n"
		headings.each { |heading| content << "| &nbsp; | [[ #{heading} => #{page.name} ]] |\n" }
		content
	end
end

class AutomaticAuthorIndex

	def initialize( wiki, create_author_pages = true, author_include_regexp = /.*/, author_exclude_regexp = /^Automatic.*/, pagename = "authors", author = "AutomaticAuthorIndexer", author_page_tail = "s pages" )
		@wiki, @create_author_pages, @author_include_regexp, @author_exclude_regexp, @pagename, @author, @author_page_tail = wiki, create_author_pages, author_include_regexp, author_exclude_regexp, pagename, author, author_page_tail
		@authors = []
		find_all_authors( wiki )
		@wiki.watch_for( :page_revised ) { |event, page, revision| 
			$stderr.puts "Got a page revised message in AutomaticAuthorIndex"
			add_author( revision ) }
	end
	
	def add_author( revision )
		return if @authors.include? revision.author
		return unless revision.author =~ @author_include_regexp
		return unless revision.author !~ @author_exclude_regexp
		@authors << revision.author
		@authors.sort!
		create_author_page_for(revision.author) if @create_author_pages
		render_author_index
	end
	
	def find_all_authors( wiki )
		wiki.each do |name, page|
			page.revisions.each do |revision|
				add_author( revision )
			end
		end
	end
	
	def render_author_index
		content = "h1. Index of Authors\n\n"
		@authors.each do |author|
			content << "* #{author}"
			if @create_author_pages
				content << " #{author}#{@author_page_tail}"
			end
			content << "\n"
		end
		@wiki.revise( @pagename, content, @author )
	end
	
	
	def create_author_page_for( author ) 
		AutomaticSummary.new( @wiki, {   :pagename => "#{author}#{@author_page_tail}" ,
										:regexp_for_author => /#{author}/,
										:author => @author,
										:only_new_pages => false,
										:sort_pages_by => :revised_on,
										:include_metadata => true,
										:summarise_revisions => true,
										:reverse_sort => true,
										:remove_deleted_pages => false,
									 } )		
		end

end

