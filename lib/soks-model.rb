require 'thread'

# Revision stores changes as a diff against the more recent content version
class Revision
	attr_reader	:number, :author, :page
	attr_reader :changes, :created_on 
	alias :revised_on :created_on
	
	def initialize( page, number, changes, author, created_on = Time.now )
		@page, @number, @changes, @author, @created_on = page, number, changes, author, created_on
	end
	
	# Recreates the content of the page AFTER this revision had been made.
	# Done by recursively applying diffs to more recent versions.
	def content
		following_revision ? following_revision.previous_content : page.content
	end
	
	# Recreateds the content of the page BEFORE this revision had been made
	def previous_content
		content.split("\n").unpatch!(@changes).join("\n")
	end
	
	def previous_revision
		return nil if number == 0
		page.revision( number - 1 )
	end
	
	def following_revision
		page.revision( number + 1 )
	end
			
	def method_missing( symbol, *args )
		raise(ArgumentError, "Revision does not respond to #{symbol}", caller) unless @page && @page.respond_to?( symbol )
		@page.send symbol, *args
	end
	
	# To allow the contents to be dumped in a class independent way.
	# Must match the order of the variables used in initialize
	def to_a() [@number, @changes, @author, @created_on] end	
end

class Page
	attr_accessor :content_lock, :name, :content, :revisions
	attr_accessor :links_lock, :links_from, :links_to, :inserted_into
	alias :to_s	:name
	
	# Returns an empty version of itself.
  	def self.empty( name )
	   empty = self.new( name )
	   empty.revise( $MESSAGES[:Type_what_you_want_here_and_click_save], "NoOne" )
	    class << empty
			def empty?; true; end
	    end
	    empty
    end

	def initialize( name )
		@content_lock, @links_lock = Mutex.new, Mutex.new
		@name, @content, @revisions = name, "", []
		@links_from, @links_to = [], [] 
		@inserted_into = []
	end
  	
  	# Revises the content of this page, creating a new revision class that stores the changes
	def revise( new_content, author )
		return nil if new_content == @content
		changes = new_content.changes_from @content
		return nil if changes.empty?
		@revisions << Revision.new( self,  @revisions.length, changes , author )
		@content = new_content
		@revisions.last
	end

	# Returns the content of this page to that of a previous version
	def rollback( number, author )
		revise( ( number < 0 ) ? $MESSAGES[:page_deleted] : @revisions[ number ].content, author )
	end
	
	def revision( number ) @revisions[ number ] end

	def deleted?
		( content =~ /^#{$MESSAGES[:page_deleted]}/i ) || 
		( content =~ /^#{$MESSAGES[:content_moved_to]} /i ) ? true : false
	end
	
	def empty?; @revisions.empty? end

	def <=>( otherpage ) self.score <=> otherpage.score end

	def score; @links_from.size + @links_to.size end
		
	def created_on; @revisions.first.created_on end
	
	def is_inserted_into( page )
		@links_lock.synchronize { @inserted_into << page unless @inserted_into.include? page }
	end
		
	def name_for_index; name.downcase end
	
	# Refactored changes_between into the String class in soks-utils
		
	# Any unhandled calls are passed onto the latest revision (e.g. author, creation time etc)
	def method_missing( symbol, *args )
		if @revisions.last && @revisions.last.respond_to?(symbol)
			@revisions.last.send symbol, *args
		else
			raise ArgumentError,"Page does not respond to #{symbol}", caller
		end
	end
end

class EmptyPage < Page
	def empty?; true; end
end

#Serves as a marker, so ImagePage and AttachmentPage can re-use the same view templates
class UploadPage < Page
end

class ImagePage < UploadPage
  def name_for_index; 	@name[10..-1].strip.downcase	end
end

class AttachmentPage < UploadPage 
  def name_for_index; 	@name[ 9..-1].strip.downcase end
end

# This class has turned into a behmoth, need to refactor.
class Wiki
	include WikiFlatFileStore
	include WikiCacheStore
	include Enumerable
	include Notify # Will notify any watchers if underlying files change
	
	attr_accessor :check_files_every
	 
	PAGE_CLASSES = [ 
	      [ /^picture of/i, ImagePage ],
	      [ /^attached/i, AttachmentPage ],
	      [ /.*/, Page ]
	    ]
	    
	CACHE_NAME = 'pages'

	def initialize( content_folder, cache_folder = nil )
		@cache_folder = cache_folder
		@folder = content_folder
		@pages = load_cache(CACHE_NAME) || {}
		@shutting_down = false
		@check_files_every = nil
		watch_for(:start) { start }
	end
	
	def start
		load_all_pages
		start_watching_files
		setup_periodic_notifications
	end
	
	def shutdown
		notify :shutdown
		sleep(1) until event_queue.empty?
		@shutting_down = true # Stop further modifications
		save_cache(CACHE_NAME, @pages)
	end
	
	def page( name )
	 	page_named( name )|| new_page( name, :empty )
	end
	
	def each( exclude_deleted = true )
		@pages.each { |name, page| yield [name, page] unless exclude_deleted && page.deleted? }
	end
	
	def exists?( name )
	    @pages.include?( name.downcase ) && !page_named( name ).deleted?
	end
  
	def revise( pagename, content, author )
		raise "Sorry! Shutting down..." if @shutting_down
		check_disk_for_updated_page pagename
		mutate( pagename ) { |page| page.revise( content, author ) }
	end
	
	def move( old_pagename, new_pagename, author )
		old_content = page(old_pagename).content
		revise( old_pagename, "#{$MESSAGES[:content_moved_to]} [[#{new_pagename}]]", author )
		revise( new_pagename, "#{$MESSAGES[:content_moved_from]} [[#{old_pagename}]]", author )
		revise( new_pagename, old_content, author )
	end
	
	def rollback( pagename, number, author )
		raise "Sorry! Shutting down..." if @shutting_down
		check_disk_for_updated_page pagename
		mutate( pagename ) { |page| page.rollback( number, author ) }
	end
	
	def delete( pagename, author )
		revise( pagename, $MESSAGES[:page_deleted], author )
	end
	
	def wipe_from_disk( pagename )
		page = page_named( pagename )
		raise "Page not deleted!" unless page.deleted?
		page.content_lock.synchronize do
			delete_files_for_page( pagename.downcase )
			@pages.delete( pagename.downcase )
		end
	end
	
	private 
	
	def setup_periodic_notifications
		PeriodicNotification.new( :year, :month, :day, :hour, :min ) do |period|
			notify period unless @shutting_down
		end	
	end
	
	def start_watching_files
		return unless check_files_every
		watch_for(check_files_every) { load_all_pages }
	end

	def new_page( name, initializer = :new )
		PAGE_CLASSES.each do |regex,klass|
			return klass.send( initializer, name) if name =~ regex
		end
	end
		
	def mutate( pagename )
		didexist = exists? pagename
		page = page_named( pagename ) || new_page( pagename )
		revision = nil
		page.content_lock.synchronize do
			# Check if the capitalisation of the page has changed
			unless page.name == pagename
				move_files_for_page( page.name, pagename )
				page.name = pagename
				notify :page_title_recapitalized, page
			end
			# Yield to the mutator block
			revision, dont_save = yield page
			# Save page if required
			if revision && dont_save != :dont_save
				save page 
				add_page_to_index( page )
			end 
		end
		if revision
			notify :page_revised, page, revision
			if page.deleted?
				notify :page_deleted, page, revision
			elsif !didexist
				notify :page_created, page, revision
			end
		end
	end
	
	def add_page_to_index( page )
		@pages[ page.name.downcase ] = page
		page
	end
	
	def page_named( pagename )
		@pages[ pagename.downcase ]
	end

end


