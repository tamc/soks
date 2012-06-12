class DeleteOldPagesHelper
	
	# Default wakes up each day at midnight and wipes all deleted pages more than 100 days old
	def initialize( wiki, event_to_check_on = :day, age_to_wipe_at = 60*60*24*100 ) 
		@wiki = wiki
		@age_to_wipe_at = age_to_wipe_at
		@wiki.watch_for(event_to_check_on) { check_and_delete_pages }
	end
	
	private
	
	def check_and_delete_pages
		@wiki.each(false) do |name, page|
			next unless page.deleted?
			next unless old_enough_to_wipe?( page )
			$LOG.warn "Permanently wiping #{name} from wiki AND from disk"
			@wiki.wipe_from_disk( name )
		end
	end
	
	def old_enough_to_wipe?( page )
		(Time.now - page.revised_on) > @age_to_wipe_at
	end
	
end

class DeleteOldRevisionsHelper
	
	AUTHOR = 'Automatic Revision Remover'
	
	# Default wakes up each day at midnight and wipes all revisions more than 100 days old if there are more than 20 revisions in the page
	def initialize( wiki, event_to_check_on = :day, age_to_wipe_at = 60*60*24*365, minimum_revisions = 20 ) 
		@wiki = wiki
		@age_to_wipe_at = age_to_wipe_at
		@maximum_revisions = minimum_revisions
		@wiki.watch_for(event_to_check_on) { check_and_delete_revisions }
	end
	
	private
	
	def check_and_delete_revisions
		@wiki.each do |name, page|
			next unless page.revisions.size > @maximum_revisions
			next unless old_enough_to_delete?( page.revisions.first )
			delete_old_revisions_from( page )
		end
	end
	
	def delete_old_revisions_from( page )
		page.content_lock.synchronize do
			delete_revisions_at_or_below = page.revisions.size - @maximum_revisions - 1
			delete_revisions_at_or_below -= 1 while not old_enough_to_delete? page.revisions[delete_revisions_at_or_below]
			
			new_revisions = []
			new_revisions << Revision.new( 	page, 
											new_revisions.length, 
											page.revisions[delete_revisions_at_or_below].content.changes_from(""), 
											AUTHOR, 
											page.revisions[delete_revisions_at_or_below].created_on )
											
			page.revisions[ (delete_revisions_at_or_below+1)..page.revisions.size].each do |revision|
				new_revisions << Revision.new( 	page, 
												new_revisions.length, 
												revision.changes, 
												revision.author, 
												revision.created_on )			
			end
			page.revisions = new_revisions
			@wiki.save_all_revisions( page )
		end
	end
	
	def old_enough_to_delete?( revision )
		(Time.now - revision.created_on) > @age_to_wipe_at
	end
end

class MergeOldRevisionsHelper
	
	# Default wakes up each hour and merges all revisions more than 24 hours old, by the same author, and that are created within an hour of each other
	def initialize( wiki, event_to_check_on = :day, minimum_age_to_merge = 60*60*24*365, maximum_time_between_revisions_for_merge = 60*60 ) 
		@wiki = wiki
		@minimum_age_to_merge = minimum_age_to_merge
		@maximum_time_between_revisions_for_merge = maximum_time_between_revisions_for_merge
		@wiki.watch_for(event_to_check_on) { check_for_pages_to_merge }
	end

	def check_for_pages_to_merge
		@wiki.each do |name, page|
			page.content_lock.synchronize do
				check_revisions_to_merge_on page
			end
		end
	end	
	
	def check_revisions_to_merge_on( page )
		return if page.empty?
		change_made = false
		new_revisions = []
		next_revision = page.revisions.first
		while next_revision
			ending_revision = next_revision
			
			while can_merge?( next_revision, ending_revision.following_revision )
				ending_revision = ending_revision.following_revision
			end
			 
			changes = 	if ending_revision == next_revision
							next_revision.changes
						else
							change_made = true
							ending_revision.content.changes_from( next_revision.previous_content )
						end
						
			new_revisions << Revision.new( 	page, 
											new_revisions.length, 
											changes, 
											ending_revision.author, 
											ending_revision.created_on )
											
			next_revision = ending_revision.following_revision
		end	
		if change_made
			page.revisions = new_revisions
			@wiki.save_all_revisions( page )
		end
	end
	
	def can_merge?( revision_a, revision_b )
		return false unless revision_a && revision_b
		return false unless same_author?( revision_a, revision_b )
		return false unless revised_at_a_similar_time?( revision_a, revision_b )
		return false unless not_to_recent?( revision_a )
		return false unless not_to_recent?( revision_b )
		true
	end
	
	def same_author?( a, b )
		a.author == b.author
	end
	
	def revised_at_a_similar_time?( a, b )
		(a.revised_on - b.revised_on).abs < @maximum_time_between_revisions_for_merge
	end
	
	def not_to_recent?( a_revision )
		(Time.now - a_revision.revised_on) > @minimum_age_to_merge
	end
end