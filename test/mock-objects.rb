$:.unshift( "contrib" )

require 'yaml'
$MESSAGES = YAML.load( IO.readlines("templates/default/views/messages.yaml").join )

require 'logger'
$LOG = Logger.new(STDOUT)
$LOG.level = Logger::WARN

begin
	require 'rubygems'
	require_gem 'ruby-breakpoint'
rescue LoadError
	$LOG.info "Breakpoint library not found.  Shouldn't matter"
end

require 'fileutils'
require 'soks'

class MockWikiStore
	include WikiFlatFileStore
	
	def initialize( folder )
		@folder = folder
		@pages = {}
	end
	
	def mutate( pagename ) 
		p yield( @pages[pagename.downcase] ||= Page.new( pagename ) )
	end
end

module TearDownableWiki
	include FileUtils

	def setup
		@wiki = Wiki.new( folder )
		@view = View.new( @wiki, 'http://testsite.com','testcontent/views' )
	end

	def teardown
		rmtree( folder )
	end

	private
	
	def create_file( name, content )
		File.open( File.join( folder, name ), 'w') { |f| f.puts content }
	end
	
	def files
		Dir.entries( folder ).delete_if { |name| name =~ /^(\.+|attachment|views)$/ }.sort
	end
	
	def folder
		@folder ||= make_folder
	end
	
	def make_folder
		mkdir( 'testcontent' )
		mkdir('testcontent/attachment')
		File.symlink(File.join(Dir.getwd,'templates/default/views'),'testcontent/views')
		'testcontent'
	end
	
	def wait_for_queue_to_empty
		sleep(0.1) until @wiki.event_queue.empty?
	end
end