#!/usr/local/bin/ruby

# This file was created automatically on <%= Time.now %>
require 'logger'

$LOG = Logger.new(STDOUT)
$LOG.level = Logger::DEBUG
$LOG.datetime_format = "%Y-%m-%d %H:%M:%S"

#Add the required libraries to the search path
begin
	require 'rubygems'
	require_gem 'Soks', '~> <%= settings[:version] %>'
	$LOG.info 'Loaded Soks from gem'
rescue LoadError
	$LOG.info "Soks Gem version <%= settings[:version] %> could not be found"
	$:.push( "<%= settings[:soks_libraries].join('","') %>" )
	require 'soks'
	$LOG.info 'Loaded Soks libraries from <%= settings[:soks_libraries].join('","') %>'
end

$LOG.info "Running Soks version #{SOKS_VERSION}"

root_directory = File.expand_path( File.dirname( __FILE__) )
$MESSAGES = YAML.load( IO.readlines("#{root_directory}/views/messages.yaml").join )
banned_titles = IO.readlines("#{root_directory}/banned_titles.txt").map { |title| title.strip }

server = WEBrick::HTTPServer.new(:Port => <%= settings[:port] %> )

wiki = Wiki.new( "#{root_directory}/content", "#{root_directory}/caches" )
wiki.check_files_every = :min

view = View.new( wiki, "<%= settings[:url] %>", "#{root_directory}/views" )
view.name = 'A Soks Wiki'
view.description = 'A Soks Wiki for you!'
view.reload_erb_each_request = false
view.dont_frame_views = ['print','rss','listrss','linksfromrss']
view.redcloth_hard_breaks = false
view.author_to_email_conversion = '@address-not-known.com'

servlet = ServletSettings.new( wiki, view )
servlet.home_page = 'Home Page'
servlet.content_types = { 'Rss' => 'application/xml', 'Listrss' => 'application/xml', 'Linksfromrss' => 'application/xml' }
servlet.force_no_cache = false

servlet.authenticators << [ /\/(edit|save|upload|delete|rollback)\//i, WEBrick::HTTPAuth::AskForUserName.new( 'No password, just enter a name') ]
servlet.authenticators << [ /.*/, WEBrick::HTTPAuth::NoAuthenticationRequired.new ]

servlet.static_file_directories[ 'Attachment' ] = "#{root_directory}/attachment"
servlet.upload_directory = 'Attachment' # Must be one of the static file directories

wiki.watch_for(:start) do |event,wiki,view|
	MergeOldRevisionsHelper.new( wiki, :day, 2, 60*60*24)
	
	AutomaticDetailedList.new( wiki, 'Known bugs' ) do |page|
		page.name =~ /^Bug:/i && page.name !~ /^Bug: Type a title here/i
	end
	
	AutomaticList.new( wiki, 'Instructions and Howtos' ) { |page| page.name =~ /^How to /i }
	AutomaticSummary.new( wiki, 'Latest News', :max_pages_to_show => 1, :reverse_sort => true) { |page| page.name =~ /^News:/i }
	AutomaticSummary.new( wiki, 'All News', :reverse_sort => true) { |page| page.name =~ /^News:/i }					

	#ViewCountHelper.new( wiki ) # Counts which are the most popular pages
	#ViewerCountHelper.new( wiki ) # Counts who visits the wiki most
	#AuthorCountHelper.new(wiki) # Counts who makes the most revisions
	
	AutomaticRecentChanges.new( wiki )

	AutomaticOnePageIndex.new( wiki ) # Index on one page, best for small wikis
	# AutomaticMultiPageIndex.new( wiki ) # One page per letter index, best for large wikis
	
	#calendar = AutomaticCalendar.new( wiki ) # Adds a series of calendar pages to the wiki
	#AutomaticUpcomingEvents.new( wiki, calendar ) # Creates a page with the next weeks events drawn from the calendar pages

	AutomaticUpdateCrossLinks.new( wiki, view, banned_titles )
end 


server.mount("/", WikiServlet, servlet  )

trap("INT") { 
	$LOG.warn "Trying to shutdown gracefully"
	server.shutdown 
	wiki.shutdown
	$LOG.info "Shutdown."
}

$LOG.warn "Starting server"
wiki.notify(:start,wiki,view)
server.start