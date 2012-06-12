require 'test/unit'
require 'mock-objects'
require 'soks-model'

class TestRevision < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_content
		page = Page.new('test page')
		page.revise('1','new author' )
		revision = page.revisions.last
		page.revise('2','new author' )
		page.revise('3','new author' )
		assert_equal('1', revision.content )
		assert_equal('', revision.previous_content )
	end
	
	def test_revision_after
		1.upto(5) { |i| @wiki.revise 'revision test', "#{i}", 'tamc2' }
		page = @wiki.page 'revision test'
		assert_equal( page.revision(1), page.revision(0).following_revision)
		assert_equal( page.revision(2), page.revision(1).following_revision )
		assert_equal( nil, page.revision(4).following_revision )
	end
	
	def test_revision_before
		1.upto(5) { |i| @wiki.revise 'revision test', "#{i}", 'tamc2' }
		page = @wiki.page 'revision test'
		assert_equal( page.revision(0), page.revision(1).previous_revision)
		assert_equal( page.revision(1), page.revision(2).previous_revision )
		assert_equal( nil, page.revision(0).previous_revision )	
	end	
end

class TestPage < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_empty
		page = Page.empty('test page')
		assert_equal( 'test page', page.name )
		assert_equal( true, page.empty? )
		assert_equal( false, page.deleted? )
		assert_equal( "[[Create test page => /edit/test page ]]", page.textile )
		assert_equal( "Type what you want here and click save", page.content )
		assert_equal( 'NoOne', page.author )
	end
	
	def test_new
		page = Page.new('test page')
		assert_equal( 'test page', page.name )
		assert_equal( true, page.empty? )
		assert_equal( false, page.deleted? )
		assert_equal( "[[Create test page => /edit/test page ]]", page.textile )
		assert_equal( '', page.content )
		#assert_equal( '', page.author )
	end
	
	def test_revision
		page = Page.new('test page')
		page.revise('new content','new author' )
		assert_equal( 'test page', page.name )
		assert_equal( false, page.empty? )
		assert_equal( false, page.deleted? )
		assert_equal( "new content", page.textile )
		assert_equal( 'new content', page.content )
		assert_equal( 'new author', page.author )	
		assert_equal( [[['+',0,'new content']]], page.changes )	
	end
	
	def test_rollback
		page = Page.new('test page')
		page.revise('1','new author' )
		page.revise('2','new author' )
		page.revise('3','new author' )
		assert_equal( 3, page.revisions.size )
		assert_equal( '3', page.content )
		page.rollback( 0, 'rollbacker' )
		assert_equal( 4, page.revisions.size )
		assert_equal( '1', page.content )
		assert_equal( 'rollbacker', page.author )
		assert_equal( [[['-',0,'3'],['+',0,'1']]], page.changes )
		page.rollback( -1, 'rollbacker' )
		assert_equal( 5, page.revisions.size )
		assert_equal( 'page deleted', page.content )
		assert_equal( true, page.deleted? )
	end
end

class TestWiki < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_change_page_caps()
		assert_equal([], files )
		@wiki.revise( 'home page', 'hello world', 'tamc2' )
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		@wiki.revise( 'Home Page', 'hello world', 'tamc2' )
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal(['Home%20Page.textile','Home%20Page.yaml'],files)
	end
	
	def test_page_delete_by_revising
		assert_equal([],files)
		@wiki.revise( 'home page', 'hello world', 'tamc2')
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		@wiki.revise( 'home page', $MESSAGES[:page_deleted], 'tamc2')
		assert_equal( false, @wiki.exists?('home page') )
		assert_equal( true, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		assert_equal( $MESSAGES[:page_deleted], @wiki.page('home page').content )
	end

	
	def test_page_delete_by_method
		assert_equal([],files)
		@wiki.revise( 'home page', 'hello world', 'tamc2')
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		@wiki.delete( 'home page', 'tamc2')
		assert_equal( false, @wiki.exists?('home page') )
		assert_equal( true, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		assert_equal( $MESSAGES[:page_deleted], @wiki.page('home page').content )
	end
	
	def test_page_delete_permanently
		assert_equal([],files)
		@wiki.revise( 'home page', 'hello world', 'tamc2')
		assert_equal( true, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal(['home%20page.textile','home%20page.yaml'],files)
		
		assert_raise( RuntimeError ) { @wiki.wipe_from_disk( 'Home Page' ) }
		
		@wiki.delete( 'Home Page', 'tamc2' )
		@wiki.wipe_from_disk( 'Home Page' )
		assert_equal( false, @wiki.exists?('home page') )
		assert_equal( false, @wiki.page('home page').deleted? )
		assert_equal([],files)
	end
end