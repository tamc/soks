require 'test/unit'
require 'fileutils'
require 'mock-objects'
require 'soks-storage'

module TestMod
	class TestClass
		def initialize(stuff)
			@stuff = stuff
		end
	end
end

class TestWikiCacheStore < Test::Unit::TestCase
	include WikiCacheStore
	include TearDownableWiki
	
	def setup
		@cache_folder = folder
	end
	
	def test_no_cache
		@cache_folder = nil
		save_cache( :test, "test class" )
		assert_equal( [], files )
		assert_equal( nil, load_cache( :test ) )
	end
	
	def test_cache
		save_cache( :test, "test class" )
		assert_equal( ['test.marshal'], files )
		assert_equal( "test class", load_cache( :test ) )
		assert_equal( [], files ) # Caches deleted on load
		assert_equal( nil, load_cache( :test ) )
	end
end

class TestWikiFlatFileStore < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_rename_if_not_url_encoded
		create_file 'a handy file.textile', 'hello world' 
		assert_equal( ['a handy file.textile'], files )
		@wiki.move_files_if_names_are_not_url_encoded
		assert_equal( ['a%20handy%20file.textile'], files )
	end
	
	def test_remove_unwanted_characters
		create_file 'a&b.textile', 'hello world'
		assert_equal( ['a&b.textile'], files )
		@wiki.move_files_if_names_are_not_url_encoded
		assert_equal( ['a%26b.textile'], files )
	end
	
	def test_avoid_overwriting_on_rename
		create_file 'a&b.textile', 'hello world'
		create_file 'a%26b.textile', 'hello world'
		assert_equal( ['a%26b.textile','a&b.textile'], files )
		@wiki.move_files_if_names_are_not_url_encoded
		assert_equal( ['a%26b.textile','a%26b1.textile'], files )
	end
	
	def test_rename_on_caps_change
		create_file 'Hello%20World.textile', 'hello world'
		create_file 'Hello%20World.yaml', 'hello world'
		assert_equal( ['Hello%20World.textile', 'Hello%20World.yaml'], files)
		@wiki.move_files_for_page( 'Hello World', 'hello world' )
		assert_equal( ['hello%20world.textile','hello%20world.yaml'], files)
	end
	
	def test_delete_files_for_page
		create_file 'Hello%20World.textile', 'hello world'
		create_file 'Hello%20World.yaml', 'hello world'
		assert_equal( ['Hello%20World.textile', 'Hello%20World.yaml'], files)
		@wiki.delete_files_for_page( 'Hello World')
		assert_equal( [], files)
	end
	
	def test_write_all_revisions
		1.upto(5) do |i|
			@wiki.revise('test page',"#{i}","test author")
		end
		
		page = @wiki.page('test page')
		assert_equal( 5, page.revisions.size )

		revisions = @wiki.load_revisions( page )
		assert_equal( 5, revisions.size )
		
		page.revisions = [ [0,[[[0,'+','5']]],'test author',Time.now] ]
		assert_equal( 1, page.revisions.size )
		@wiki.revise('test page','extra revision', 'second author')
		assert_equal( 2, page.revisions.size )
		assert_equal( 5, @wiki.load_revisions( page ).size )
		
		@wiki.save_all_revisions( page )
		revisions = @wiki.load_revisions( page )
		assert_equal( 2, revisions.size )
		assert_equal( 'second author', revisions[1].author )
	end
	
	private
	
	def create_file( name, content )
		File.open( File.join( folder, name ), 'w') { |f| f.puts content }
	end
	
end