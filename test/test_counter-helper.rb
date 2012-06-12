require 'test/unit'
require 'fileutils'
require 'mock-objects' 
require 'generator'
require 'helpers/counter-helpers' 

class TestViewCountHelper < Test::Unit::TestCase
	include TearDownableWiki

	def test_notification
		 results = []
		 @wiki.watch_for(:page_viewed) { |*results| }
		 @view.render( 'test-page','view','test-viewer')
		 wait_for_queue_to_empty
		 assert_equal( :page_viewed, results[0] )
		 assert_equal( 'test-page', results[1].name )
		 assert_equal( 'view', results[2] )
		 assert_equal( 'test-viewer', results[3] )	
	end
	
	def test_total_count
		count = ViewCountHelper.new(@wiki).counts
		@view.render( 'test-page','view','test-viewer')
		@view.render( 'test-page','view','test-viewer')
		@view.render( 'test-page','view','test-viewer')
		wait_for_queue_to_empty
		assert_equal( 3, count.total )
	end
		
	def	test_page_count
		count = ViewCountHelper.new(@wiki, ['view'], 'Popular Pages', :test_event, 2 ).counts
		@wiki.revise( 'count1','1','t1')
		@wiki.revise( 'count2','2','t2')
		@wiki.revise( 'count3','3','t3')
		3.times { @view.render( 'count1' ) }
		3.times { @view.render( 'count1', 'edit' ) }
		2.times { @view.render( 'count2' ) }
		1.times { @view.render( 'count3' ) }
		wait_for_queue_to_empty
		p1,p2,p3 = @wiki.page('count1'), @wiki.page('count2'), @wiki.page('count3')
		assert_equal( 3, count[p1.name] )
		assert_equal( 2, count[p2.name] )
		assert_equal( 1, count[p3.name] )
		assert_equal( 6, count.total )
	end
	
	def test_page_render
		start_time = Time.now
		test_page_count
		@wiki.notify( :test_event )
		wait_for_queue_to_empty
		content = @wiki.page('Popular Pages').content.split "\n"
		[	[ 0, "h1. Popular Pages" ],
			[ 4, "| count1 | 3 |" ],
			[ 5, "| count2 | 2 |" ],
			[ 6, "| 1 others | 1 |" ],
			[ 7, "| *Total* | *6* |" ] ].each do |i,line|
				assert_equal line, content[i]
		end
	end
	
end

class TestViewerCountHelper < Test::Unit::TestCase
	include TearDownableWiki

	def test_notification
		 results = []
		 @wiki.watch_for(:page_viewed) { |*results| }
		 @view.render( 'test-page','view','test-viewer')
		 wait_for_queue_to_empty
		 assert_equal( :page_viewed, results[0] )
		 assert_equal( 'test-page', results[1].name )
		 assert_equal( 'view', results[2] )
		 assert_equal( 'test-viewer', results[3] )	
	end
	
	def test_total_count
		count = ViewerCountHelper.new(@wiki).counts
		@view.render( 'test-page','view','test-viewer')
		@view.render( 'test-page','view','test-viewer')
		@view.render( 'test-page','view','test-viewer')
		wait_for_queue_to_empty
		assert_equal( 3, count.total )
	end
		
	def	test_viewer_count
		count = ViewerCountHelper.new(@wiki, ['view'], 'Popular Pages', :test_event, 2 ).counts
		@wiki.revise( 'count1','1','t1')
		@wiki.revise( 'count2','2','t2')
		@wiki.revise( 'count3','3','t3')
		3.times { @view.render( 'count1', 'view', "Author1" ) }
		3.times { @view.render( 'count1', 'edit', "Author1" ) }
		2.times { @view.render( 'count2', 'view', "Author2" ) }
		1.times { @view.render( 'count3', 'view', "Author3" ) }
		wait_for_queue_to_empty
		assert_equal( 3, count['Author1'] )
		assert_equal( 2, count['Author2'] )
		assert_equal( 1, count['Author3'] )
		assert_equal( 6, count.total )
	end
	
	def test_page_render
		start_time = Time.now
		test_viewer_count
		@wiki.notify( :test_event )
		wait_for_queue_to_empty
		content = @wiki.page('Popular Pages').content.split "\n"
		[	[ 0, "h1. Popular Pages" ],
			[ 4, "| Author1 | 3 |" ],
			[ 5, "| Author2 | 2 |" ],
			[ 6, "| 1 others | 1 |" ],
			[ 7, "| *Total* | *6* |" ] ].each do |i,line|
				assert_equal line, content[i]
		end
	end
end


class TestAuthorCountHelper < Test::Unit::TestCase
	include TearDownableWiki

	
	def test_total_count
		count = AuthorCountHelper.new(@wiki,'Principal Authors', :test_event, 2 ).counts
		@wiki.revise( 'count1','1','t1')
		@wiki.revise( 'count2','2','t2')
		@wiki.revise( 'count3','3','t3')
		wait_for_queue_to_empty
		assert_equal( 3, count.total )
	end
		
	def	test_author_count
		count = AuthorCountHelper.new(@wiki,'Principal Authors', :test_event, 2 ).counts
		@wiki.revise( 'count1','1','t1')
		@wiki.revise( 'count2','1','t1')
		@wiki.revise( 'count2','2','t2')
		@wiki.revise( 'count3','1','t1')
		@wiki.revise( 'count3','2','t2')
		@wiki.revise( 'count3','3','t3')
		wait_for_queue_to_empty
		assert_equal( 3, count['t1'] )
		assert_equal( 2, count['t2'] )
		assert_equal( 1, count['t3'] )
		assert_equal( 6, count.total )
	end
	
	def test_page_render
		start_time = Time.now
		test_author_count
		@wiki.notify( :test_event )
		wait_for_queue_to_empty
		content = @wiki.page('Principal Authors').content.split "\n"
		[	[ 0, "h1. Principal Authors" ],
			[ 4, "| t1 | 3 |" ],
			[ 5, "| t2 | 2 |" ],
			[ 6, "| 1 others | 1 |" ],
			[ 7, "| *Total* | *6* |" ] ].each do |i,line|
				assert_equal line, content[i]
		end		
	end
end