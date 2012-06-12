require 'test/unit'
require 'mock-objects'
require 'helpers/maintenance-helpers'

class TestDeleteOldPages < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		DeleteOldPagesHelper.new( @wiki, :an_event, 2 )
	end
	
	def test_delete_old_pages
		assert_equal([],files)
		@wiki.revise( 'home page', 'hello world', 'tamc2')
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		
		@wiki.delete( 'home page', 'tamc2')
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should be too soon
		assert_equal( false, @wiki.exists?('home page') )
		assert_equal( true, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)		
		
		sleep( 2 ) 
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should now have deleted
		assert_equal( false, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal([],files)		
	end
	
end

class TestDeleteOldRevisions < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		DeleteOldRevisionsHelper.new( @wiki, :an_event, 2, 2)
	end
	
	def test_delete_old_revisions
		1.upto(5) do |i|
			@wiki.revise('revision delete test page',"#{i}","test author")
		end
		page = @wiki.page('revision delete test page')
		assert_equal(5,page.revisions.size)
		
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should be too soon
		assert_equal(5,page.revisions.size)
		
		sleep( 2 ) 
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should now have turned last 3 revisions into one
		assert_equal(3,page.revisions.size)
		assert_equal('Automatic Revision Remover',page.revisions.first.author)
		assert_equal('3',page.revisions.first.content)
	end
end

class TestMergeOldRevisions < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		MergeOldRevisionsHelper.new( @wiki, :an_event, 2, 10)
	end
	
	def test_merge_old_revisions
		1.upto(3) do |i|
			@wiki.revise('revision merge test page',"#{i}","author1")
		end
		3.upto(5) do |i|
			@wiki.revise('revision merge test page',"#{i}","author2")
		end
		page = @wiki.page('revision merge test page')
		assert_equal(5,page.revisions.size)
		
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should be too soon
		assert_equal(5,page.revisions.size)
		
		sleep( 2 ) 
		@wiki.notify(:an_event )
		wait_for_queue_to_empty
		
		# Should now have merged each author's revisions
		assert_equal(2,page.revisions.size)
		assert_equal('3',page.revision(0).content)
		assert_equal('5',page.revision(1).content)
	end
end