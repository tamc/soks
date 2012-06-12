module WikiCacheStore
	
	CACHE_EXTENSION = ".marshal"
	
	def load_cache( cache_name )
		return nil unless @cache_folder
		
		cache = nil
		
		File.open( cache_filename_for( cache_name ) ) do |f|
			cache = Marshal.load(f)
		end
		
		File.delete( cache_filename_for( cache_name ) )
		
		$LOG.info "Loaded #{cache_name} cache"
		
		return cache
		
		rescue ArgumentError
			$LOG.warn "#{cache_name} cache corrupt (bad characters in file)"
			return nil 
		
		rescue EOFError
			$LOG.warn "#{cache_name} cache corrupt (unexpected end of file)"
			return nil 
			
		rescue Errno::ENOENT
			$LOG.warn "#{cache_name} cache not found"
			return nil
	end
	
	def save_cache( cache_name, cache_object )
		return nil unless @cache_folder
		File.open( cache_filename_for( cache_name ), 'w' ) do |f|
			f.puts Marshal.dump(cache_object)
		end
	end
	
	def cache_filename_for( name )
		File.join( @cache_folder, "#{name}#{CACHE_EXTENSION}")
	end

end

module WikiFlatFileStore

	CONTENT_EXTENSION = '.textile'
	REVISIONS_EXTENSION = '.yaml'
	DEFAULT_AUTHOR = 'the import script' 

	def load_all_pages
		move_files_if_names_are_not_url_encoded
		pages_on_disk = Dir[ File.join( @folder, "*#{CONTENT_EXTENSION}" ) ].map { |filename| page_name_for( filename )}
		pages_in_memory = @pages.values.map { |page| page && page.name }
		( pages_in_memory.compact | pages_on_disk ).each do |pagename| 
			if check_disk_for_updated_page( pagename, true ) == :file_does_not_exist
				revise( pagename, $MESSAGES[:page_deleted], DEFAULT_AUTHOR )
			end
		 end
	end
	
	def save( page )
		save_content( page )
		save_last_revision( page )
	end
	
	def delete_files_for_page( page_name )
		File.delete( filename_for_content( page_name ), filename_for_revisions( page_name ) )
	end
	
	def move_files_for_page( old_page_name, new_page_name )
		File.rename( filename_for_content( old_page_name ), filename_for_content( new_page_name ) )
		File.rename( filename_for_revisions( old_page_name ), filename_for_revisions( new_page_name ) )
	end

	def check_disk_for_updated_page( pagename, force = false )
		return unless force || self.check_files_every # We don't care about file changes 
		filename = filename_for_content( pagename )
		return :file_does_not_exist unless File.exists?( filename ) # File doesn't exist on disk
		return load_page( filename ) unless page_named( pagename )# File is new on the disk, but not yet in memory 
		return load_page( filename ) if content_newer_than_revisions?( page_named(pagename) ) # File is newer on disk
		return nil
	end
	
	def load_page( filename )
		mutate( page_name_for( filename ) ) do |page|
			disk_content = load_content( page )
			return nil if disk_content == page.content # No change, disk is the same as memory

			# We now know that the content on disk is different from that in memory
			
			page.revisions = load_revisions( page ) if page.revisions.empty? # Load revisions from disk if none known 
			# assumes disk revisions are ALWAYS up to date with memory?
			
			# We now know what the page content and the page revisions should be. But not if the revisions are up to date	
			if content_newer_than_revisions?( page ) # The textile file has been modified, but the array file has not been updated to match
				page.content = reconstruct_content_from_revisions( page.revisions )
				page.revise( disk_content, DEFAULT_AUTHOR )
				save_last_revision( page )
			else # The textile file and the array file are in sync.
				page.content = disk_content
			end
		
			add_page_to_index( page )
			[ page.revisions.last, :dont_save ]
		end
	end

	def load_content( page )
		IO.readlines( filename_for_content( page.name ) ).join
	end

	def load_revisions( page )
		return [] unless File.exists?( filename_for_revisions( page.name ) )
		revisions = []
		begin
			File.open( filename_for_revisions( page.name ) ) { |file| 
				YAML.each_document( file ) { |array|
					next unless array.is_a? Array 
					next unless array.size == 4
					next unless array[0].is_a? Integer 
					revisions[ array[0] ] = Revision.new( page, *array ) } 
			}
		rescue
			$LOG.error "Error loading revisions with #{$!.to_s} in file #{page.name}"
		end
		revisions.each_with_index { |r,i| $LOG.error "#{page.name} missing revision #{i}" unless r }
		revisions
	end
	
	def content_newer_than_revisions?( page )
		return true if page.empty?
		File.ctime(filename_for_content( page.name )) > File.ctime(filename_for_revisions(page.name))
	end

	def reconstruct_content_from_revisions( revisions )
		content = []
		revisions.each { |revision| content = Diff::LCS.patch( content, revision.changes, :patch ) }
		content.join("\n")
	end

	def move_files_if_names_are_not_url_encoded
		Dir[ File.join( @folder, "*#{CONTENT_EXTENSION}" ) ].each do |filename|
			basename = File.basename( filename, '.*')
			next if basename.url_decode.url_encode == basename # All ok, so no worry
			new_name = File.join( File.dirname(filename), File.unique_filename( File.dirname(filename), basename.url_decode.url_encode +  File.extname( filename) ) )
			File.rename(filename, new_name )
		end
	end
	
	def save_content( page )
		File.open(filename_for_content( page.name ), 'w' ) { |file| file.puts page.content }
	end
	
	# Appends the last revision onto the yaml file	
	def save_last_revision( page )
		$LOG.info "Saving revisions for #{page.name}"
		File.open(filename_for_revisions( page.name ), 'a' ) do |file| 
			YAML.dump( page.revisions.last.to_a, file )
			file.puts # Needed to ensure that documents are separated
		end
	end
	
	def save_all_revisions( page )
		$LOG.warn "Saving all revisions for #{page.name}"
		File.open(filename_for_revisions( page.name ), 'w' ) do |file|
			page.revisions.each do |revision| 
				YAML.dump( revision.to_a, file )
				file.puts # Needed to ensure that documents are separated
			end
		end
	end
	
	def page_name_for( filename )
		File.basename( filename, '.*').url_decode	
	end
	
	def filename_for_content( pagename )
		File.join( @folder, "#{pagename.url_encode}#{CONTENT_EXTENSION}" )
	end

	def filename_for_revisions( pagename )
		File.join( @folder, "#{pagename.url_encode}#{REVISIONS_EXTENSION}" )
	end
end
	