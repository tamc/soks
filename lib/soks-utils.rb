# This is a bit like observable, but for events
module Notify
	
	# Will notify in a separate low priority thread
	def watch_for( *events , &action_block )
		self.event_queue.watch_for( events, action_block )
	end
	
	# Will notify in the running high priority thread (ie will block response to user)
	def watch_attentively_for( *events, &action_block )
		self.event_queue.watch_attentively_for( events, action_block )
	end
	
	def notify( event, *messages)
		raise "Sorry! Shutting down..." if @shutting_down
		self.event_queue.event( event, messages )
	end
	
	def event_queue
		@event_queue ||= EventQueue.new
	end
	
end

class EventQueue

	def initialize
		@queue = Queue.new
		start_thread
	end
	
	def event( event, messages )
		# $LOG.warn "#{event}, #{messages}"
		check_thread_ok
		@queue.enq [ event, messages ]
		$LOG.warn "Notification queue backlog of #{@queue.size}" if @queue.size > 100
		notify_attentive_watchers( event, *messages )
	end
	
	# Will call the action_block lazily
	def watch_for( events , action_block )
		events.each { |event| watchers_for(event) << action_block }
	end
	
	# Will call the action_block imediately
	def watch_attentively_for( events, action_block )
		events.each { |event| attentive_watchers_for(event) << action_block }
	end
	
	def empty?
		@queue.empty? && !@notifying_flag
	end
	
	private
	
	def check_thread_ok
		start_thread unless @thread && @thread.alive?
	end
	
	def start_thread
		@thread = Thread.new do
			loop do
				check_for_events
			end
		end
		@thread.priority = -1 
	end
	
	def check_for_events
		event, messages = @queue.deq
		notify( event, *messages )
	end
	
	def notify( event, *messages)
		@notifying_flag = true
		watchers_for( event ).each { |action_block|
			begin 
				action_block.call(event, *messages)
			rescue StandardError => err
				$LOG.warn "ERROR #{err}: #{event} - #{messages.join(' ')}"
				err.backtrace.each { |s| $stderr.puts s }
			end 
		}
		@notifying_flag = false
	end
	
	def watchers_for( event )
		watchers[ event ] ||= []
	end
	
	def watchers
		@watchers ||= {}
	end
	
	def notify_attentive_watchers( event, *messages )
		attentive_watchers_for( event ).each { |action_block| 
			begin	
				action_block.call(event, *messages)
			rescue StandardError => err
				$stderr.puts "ERROR #{err}: #{event} - #{messages.join(' ')}"
				err.backtrace.each { |s| $stderr.puts s }
			end  
		}
	end
	
	def attentive_watchers_for( event )
		attentive_watchers[ event ] ||= []
	end
	
	def attentive_watchers
		@attentive_watchers ||= {}
	end
end

class PeriodicNotification
	
	def initialize( *notify_about, &block)
		@block = block
		notify_about.each do |period|
			start_thread( period )
		end			
	end
	
	private
	
	def start_thread( period )
		Thread.new( period ) do |period|
			while true
				sleep seconds_to_next_period( period )
				@block.call( period )
			end
		end
	end
	
	def seconds_to_next_period( period )
		Time.now.next( period ) - Time.now
	end
end

class String
	# Return the left bit of a string e.g. "String".left(2) => "St"
  	def left( length ) self.slice( 0, length ) end  
  
	# Encode the string so it can be used in urls (code coppied from CGI)
	def url_encode
	 self.gsub(/([^a-zA-Z0-9]+)/n) do
	   '%' + $1.unpack('H2' * $1.size).join('%').upcase
	 end
	end

	# Decode a string url encoded so it can be used in urls (code coppied from CGI)
	def url_decode
	 self.gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
	   [$1.delete('%')].pack('H*')
	 end
	end  	

  	# Return the first n lines of the string
  	def first_lines( lines = 1 ) 
  		self.split("\n")[0,lines].join("\n")
  	end

	def close_unmatched_html
		start_tags = self.scan(/<(\w+)[^>\/]*?(?!\/)>/)
		end_tags = self.scan(/<\/(\w+)[^>\/]*?>/)
		return self if start_tags.size == end_tags.size
		missing_tags = start_tags - end_tags
		text = self.dup
		missing_tags.each do |tag|
			text << "</#{tag[0]}>"
		end
		text
	end
	
	# Removes punctuation and spaces that can cause problems with page names
	#def to_valid_pagename
	#	self.tr('\\\[]?{}#&^`<>/','').strip
	#end
	
	#Returns the changes between the lines of this string and another
	def changes_from( other_string )
		other_string.split("\n").diff( self.split("\n") ).map { |changeset| changeset.map { |change| change.to_a } }
	end
	
end

class FiniteUniqueList
	include Enumerable
	
	attr_accessor :max_size
	
	def initialize( max_size = nil, reverse = false, sort_by = nil )
		@max_size = max_size
		@list = Array.new
		@sort_by = sort_by
		@reverse = reverse
	end

	def add( item )
		remove( item )
		@list << item
		sort_items
		remove_excess_items
	end
	
	def remove( item )
		@list.delete( item )
	end
	
	def each
		if @reverse
			@list.reverse_each { |item| yield item }
		else
			@list.each { |item| yield item }
		end
	end
	
	def empty?; @list.empty? end
	
	def include?( item )
		@list.include?( item )
	end
	
	private 
	
	def remove_excess_items
		return unless @max_size
		while @list.size > @max_size
			@list.shift
		end
	end
	
	def sort_items
		return unless @sort_by
		@list = @list.sort_by { |item| item.send( @sort_by ) }
	end
end

# Kindly written by Bil Kleb
class Numeric
 # similar to  distance_of_time_in_words as found in
 # actionpack-1.1.0/lib/action_view/helpers/date_helper.rb
 def to_time_units
  seconds = self.round
  case seconds
   when 0:                                "fraction of a second"
   when 1:                                "second"
   when 2..45:                            "#{seconds} seconds"
   when 46..90:                           "minute"
   when 91..(60*45):                      "#{(seconds.to_f/60.0).round} minutes"
   when (60*45)..(60*90):                 "hour"
   when (60*90)..(60*60*22):              "#{(seconds.to_f/60.0/60.0).round} hours"
   when (60*60*22)..(60*60*36):           "day"
   when (60*60*36)..(60*60*24*26):        "#{(seconds.to_f/60.0/60.0/24.0).round} days"
   when (60*60*24*26)..(60*60*24*45):     "month"
   when (60*60*24*45)..(60*60*24*30*11):  "#{(seconds.to_f/60.0/60.0/24.0/30.0).round} months"
   when (60*60*24*30*11)..(60*60*24*500): "year"
  else                                    "#{(seconds.to_f/60.0/60.0/24.0/365.0).round} years"
  end
 end
end

class Time
	
	# Returns 'yesterday', 'tomorrow' for date relative to now
	def relative_day
		# Days difference
		case self.days_from( Time.now ) 			
		when -7..-2	; 	strftime('Last %A')
		when -1 	; 	"Yesterday"
		when 0 		; 	"Today"
		when 1 		; 	"Tomorrow"
		when 2..7	;	strftime('%A')
		else		; 	strftime( (Time.now.year == self.year) ? '%d %b' :'%d %b %Y')
		end
	end

	def days_from( other_time )
		((Time.local(self.year, self.month, self.day)-Time.local(other_time.year, other_time.month, other_time.day))/(24*60*60)).round
	end
	
	# Checks whether two times are on the same day
	def same_day?( other_time )
		return false unless other_time.year == self.year
		return false unless other_time.yday == self.yday
		return true
	end
	
	# Returns the Time at the next occurance of the period
	def next( period )
		case period
		when :sec, :second
			next_time = self + 1
			Time.local( next_time.year, next_time.month, next_time.day, next_time.hour, next_time.min, next_time.sec )
		when :min, :minute
			next_time = self + 60
			Time.local( next_time.year, next_time.month, next_time.day, next_time.hour, next_time.min )
		when :hour
			next_time = self + ( 60*60 )
			Time.local( next_time.year, next_time.month, next_time.day, next_time.hour)
		when :day
			next_time = self + ( 60*60*24 )
			Time.local( next_time.year, next_time.month, next_time.day)
		when :mon, :month
			next_time = self + ( 60*60*24*(32-self.day) )
			Time.local( next_time.year, next_time.month)
		when :year
			next_time = self + ( 60*60*24*(367-self.yday) )
			Time.local( next_time.year )
		end
	end
	
end

class File
	
	def self.unique_filename( path, filename )
		filename.tr!(' ','') # Unfortunately no spaces permitted in redcloth links
		return filename unless exist?( join( path, filename ) )# Leave as is, if doesn't exist
		name, counter, extension = basename( filename, '.*'), 1, extname( filename )
		counter += 1 while exist?( join( path, "#{name}#{counter}#{extension}" ) )
		return "#{name}#{counter}#{extension}"
	end

end
