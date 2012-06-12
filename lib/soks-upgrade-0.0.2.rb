require 'soks-utils'
require 'yaml'
	
	# This is the definition of Revision from v-0-0-2.
	# Much smaller than the current definition. sigh.
	class Revision
		attr_reader :number, :changes, :created_at, :author

		def initialize( number, changes, author )
			@number, @changes, @author = number, changes, author
			@created_at = Time.now
		end
	
		def content( page )
			page.revision( @number + 1 ) ? page.revision( @number + 1 ).previous_content( page ) : page.content
		end

		def previous_content( page )
			content( page ).split("\n").unpatch!(@changes).join("\n")
		end
	end

class SoksUpgrade
		
	def load_old_revisions( filename )
		File.open( filename ) { |file| return Marshal.load( file ) }
	end
	
	def save_new_revisions( old_filename, revisions )
		File.open(new_filename_for_old( old_filename ), 'w' ) do |file| 
			revisions.each do |revision|
				YAML.dump( [revision.number, revision.changes, revision.author, revision.created_at ] , file )
				file.puts
			end
		end
	end
	
	def new_filename_for_old( old_filename )
		basename = File.basename( old_filename, '.*')
		new_extension = '.yaml'
		File.join( File.dirname(old_filename), basename ) + new_extension
	end

	def upgrade_revisions( directory )
		search = File.join( directory,'content', "*.marshal" )
		Dir[ search ].each do |filename|
			puts "Upgrading #{filename}"
			save_new_revisions( filename, load_old_revisions( filename ))
			File.delete filename
		end
	end
	
	def upgrade_textile( filename )
		textile = IO.readlines( filename ).join
		textile.gsub!(/\[\[\s*(.*?)\s*(|:\s*(.*?)\s*)\]\]/) do |m|
			title, page = $1, $3
			page ? "[[ #{title} => #{page} ]]" : "[[ #{title} ]]"
		end
		File.open( filename, 'w' ) { |f| f.puts textile }	
	end
	
	def upgrade_content( directory )
		search = File.join( directory,'content', "*.textile" )
		Dir[ search ].each do |filename|
			puts "Upgrading #{filename}"
			upgrade_textile( filename )
		end
	end	

end