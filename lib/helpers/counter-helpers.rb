class CounterObject
	
	attr_reader :total,:start_time
	
	def initialize( show_top = 20 )
		@show_top = show_top
		@counts = {}
		@total, @start_time = 0, Time.now
	end
	
	def count( thing_to_count )
		@counts[thing_to_count] = ( @counts[thing_to_count] || 0 ) + 1
		@total += 1
	end
	
	def each
		running_total, displayed = 0, 0
		@counts.sort_by { |thing,count| count }.reverse_each do |thing,count|
			break if @show_top && ( displayed >= @show_top )
			displayed += 1
			running_total += count
			yield thing, count
		end
		if @show_top && (@show_top < @counts.size)
			yield "#{@counts.size - @show_top} others", @total-running_total
		end
		yield "*Total*", "*#{@total}*"
	end
	
	def [](thing)
		@counts[thing]
	end
	
	def empty?
		@counts.empty?
	end

end

class ViewCountHelper
	
	attr_reader :counts
	
	def initialize( wiki, views_to_count = [ 'view' ], page_name = 'Popular Pages', update_page_every = :hour, show_top = 20, cache_name = 'viewcount' )
		@wiki = wiki
		@counts = wiki.load_cache(cache_name) || CounterObject.new(show_top)
		@views_to_count, @page_name = views_to_count, page_name
		@wiki.watch_for(:page_viewed) { |event,page,view,author| count page, view, author }
		@wiki.watch_for(update_page_every) { render_count_page }
		@wiki.watch_for(:shutdown) { wiki.save_cache(cache_name,@counts)}
	end
	
	def count( page, view, author )
		return unless should_count?( page, view, author )
		@counts.count(count_key( page, view, author ))
	end
	
	def should_count?( page, view, author )
		@views_to_count.include?( view.downcase )
	end
	
	def count_key( page, view, author )
		page.name
	end
	
	def render_count_page
		content = "h1. #{@page_name}\n\n"
		content << "Count since #{@counts.start_time}. Updated on #{Time.now}\n\n"
		@counts.each do |page,count|
			content << "| #{page} | #{count} |\n"
		end
		@wiki.revise( @page_name, content, 'AutomaticCounter' )
	end
	
end

class ViewerCountHelper < ViewCountHelper
	
	def initialize( wiki, views_to_count = [ 'view' ], page_name = 'Prolific Viewers', update_page_every = :hour, show_top = 20, cache_name = 'viewercount' ) 
		super( wiki, views_to_count, page_name, update_page_every, show_top, cache_name )
	end
	
	def count_key( page, view, author )
		author
	end
end

class AuthorCountHelper
	
	attr_reader :counts
	
	def initialize( wiki, page_name = 'Principal Authors', update_page_every = :hour, show_top = 20, cache_name = 'authorcount' )
		@wiki = wiki
		@counts = wiki.load_cache(cache_name) || CounterObject.new(show_top) 
		count_from_scratch if @counts.empty?
		@page_name =  page_name
		@wiki.watch_for(:page_revised) { |event,page,revision| count page, revision }
		@wiki.watch_for(update_page_every) { render_count_page }
		@wiki.watch_for(:shutdown) { wiki.save_cache(cache_name,@counts)}
	end
	
	def count_from_scratch
		@wiki.each do |pagename,page|
			page.revisions.each do |revision|
				count( page, revision )
			end
		end
	end
	
	def count( page, revision )
		return unless should_count?( page, revision )
		@counts.count(count_key( page, revision ))
	end
	
	def should_count?( page, revision )
		revision.author !~ /^Automatic/
	end
	
	def count_key( page, revision )
		revision.author
	end
	
	def render_count_page
		content = "h1. #{@page_name}\n\n"
		content << "Count since #{@counts.start_time}. Updated on #{Time.now}\n\n"
		@counts.each do |page,count|
			content << "| #{page} | #{count} |\n"
		end
		@wiki.revise( @page_name, content, 'AutomaticCounter' )
	end
	
end