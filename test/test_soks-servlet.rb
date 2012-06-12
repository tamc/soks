require 'test/unit'
require 'fileutils'
require 'mock-objects' 

class MockFileData
	
	attr_accessor :filename, :list
	
	def initialize( filename = 'test file.txt', list = ['0123456789'])
		@filename, @list = filename, list
	end
end

class WEBrick::HTTPServlet::FileHandler
	
	def service( request, response )
		response.body = "File #{request.script_name.downcase} #{request.path_info}"
	end
	
end

class MockRequest < Hash

	def path_info
		return path
	end
	
	def method_missing( method, *args )
		if method.to_s[-1,1] == '=' && args.length == 1
			self[method.to_s[0...-1].to_sym] = args.first
		else
			self[method]
		end
	end
	
end

class MockResponse < Hash
	
	def set_redirect( type, destination )
		self[:redirect_type] = type
		self[:redirect_destination] = destination
	end	
	
	def method_missing( method, *args )
		if method.to_s[-1,1] == '=' && args.length == 1
			self[method.to_s[0...-1].to_sym] = args.first
		else
			self[method]
		end
	end
end

class MockServer
	
	def config
		{:Logger => 'a' }
	end
	
end

class TestWikiServlet < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		@servlet = WikiServlet.new( MockServer.new, ServletSettings.new(@wiki,@view) )
		@servlet.settings.static_file_directories['Attachment'] = "#{folder}/attachment"
		@servlet.settings.upload_directory = 'Attachment'
	end
	
	def test_static_files
		@servlet.service( re = MockRequest[ :path => '/favicon.ico' ], rp = MockResponse.new )
		assert_equal( nil, rp[:redirect_destination] )
		assert_equal( "File attachment /favicon.ico", rp[:body])
		@servlet.service( re = MockRequest[ :path => '/robots.txt' ], rp = MockResponse.new )
		assert_equal( nil, rp[:redirect_destination] )
		assert_equal( "File attachment /robots.txt", rp[:body])
	end
	
	def test_standard_attachment
		@servlet.service( re = MockRequest[ :path => '/attachment/logo.jpg' ], rp = MockResponse.new )
		assert_equal( nil, rp[:redirect_destination] )
		assert_equal( "File attachment /attachment/logo.jpg", rp[:body])
	end
	
	def test_second_attachment
		@servlet.settings.static_file_directories['Www'] = '/var/www'
		test_standard_attachment
		@servlet.service( re = MockRequest[ :path => '/www/logo.jpg' ], rp = MockResponse.new )
		assert_equal( nil, rp[:redirect_destination] )
		assert_equal( "File www /www/logo.jpg", rp[:body])
	end
	
	def test_redirect_to_home_page
		@servlet.service( re = MockRequest[ :path => '/' ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/HomePage', rp[:redirect_destination])
	end
	
	def test_redirect_to_view
		@servlet.service( re = MockRequest[ :path => '/randompage' ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/randompage', rp[:redirect_destination])
	end
	
	def test_missing_view
		assert_raise(WEBrick::HTTPStatus::NotFound) { @servlet.service( re = MockRequest[ :path => '/missing/randompage', :user => 'test user' ], rp = MockResponse.new ) }
	end
	
	def test_view_page
		@wiki.revise('test view','hello world','tamc2')
		assert_equal('hello world', @wiki.page('test view').content )
		@servlet.service( re = MockRequest[ :path => '/view/test view', :user => 'test user', :query => {} ], rp = MockResponse.new )
		assert_equal( nil, rp[:redirect_destination] )
		assert_match( /<p>hello world<\/p>/, rp[:body])
	end
	
	def test_name_to_url_conversion
		@wiki.revise('page!','exclamation','one')
		@wiki.revise('page?','question','one')
		@servlet.service( re = MockRequest[ :path => '/view/Page', :user => 'test user', :query => {} ], rp = MockResponse.new )
		assert_match( /<p>exclamation<\/p>/, rp[:body])
		@servlet.service( re = MockRequest[ :path => '/view/Page-2', :user => 'test user', :query => {} ], rp = MockResponse.new )
		assert_match( /<p>question<\/p>/, rp[:body])
	end
	
	def test_create_page
		@servlet.service( re = MockRequest[ :path => '/save/test save', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'test save' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestSave', rp[:redirect_destination] )
		page = @wiki.page('test save')
		assert_equal( 'test user', page.author )
		assert_equal( 'hello world', page.content )
	end

	def test_revise_page
		@wiki.revise('test save','stuff','someone')
		@servlet.service( re = MockRequest[ :path => '/save/TestSave', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'test save' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestSave', rp[:redirect_destination] )
		page = @wiki.page('test save')
		assert_equal( 'test save',page.name )
		assert_equal( 'test user', page.author )
		assert_equal( 'hello world', page.content )
	end
	
	def test_revise_prefix_page
		@servlet.service( re = MockRequest[ :path => '/save/test save', :user => 'test user', :query => { 'content' => 'hello world', 'titleprefix' => 'test ', 'newtitle' => 'save' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestSave', rp[:redirect_destination] )
		page = @wiki.page('test save')
		assert_equal( 'test user', page.author )
		assert_equal( 'hello world', page.content )
	end
	
	def test_revise_change_capitalisation_on_page	
		@servlet.service( re = MockRequest[ :path => '/edit/test caps', :user => 'test user', :query => {} ], rp = MockResponse.new )
		@servlet.service( re = MockRequest[ :path => '/save/TestCaps', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'test caps' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestCaps', rp[:redirect_destination] )
		assert_equal('test caps', @wiki.page('test caps').name )
		@servlet.service( re = MockRequest[ :path => '/save/TestCaps', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'Test Caps' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestCaps', rp[:redirect_destination] )
		assert_equal('Test Caps', @wiki.page('test caps').name )
	end
	
	def test_revise_and_move_page
		@wiki.revise('test view','hello world','tamc2')
		assert_equal('hello world', @wiki.page('test view').content )
		@servlet.service( re = MockRequest[ :path => '/save/test view', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'test save' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestSave', rp[:redirect_destination] )
		newpage = @wiki.page('test save')
		assert_equal( 'test user', newpage.author )
		assert_equal( 'hello world', newpage.content )
		oldpage = @wiki.page('test view')
		assert_equal( 'test user', oldpage.author )
		assert_equal( 'content moved to [[test save]]', oldpage.content )
	end
	
	def test_revise_and_dont_move_template_page
		@wiki.revise('test type a title here','hello world','tamc2')
		@servlet.service( re = MockRequest[ :path => '/save/test type a title here', :user => 'test user', :query => { 'content' => 'hello world', 'newtitle' => 'test save' } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestSave', rp[:redirect_destination] )
		newpage = @wiki.page('test save')
		assert_equal( 'test user', newpage.author )
		assert_equal( 'hello world', newpage.content )
		oldpage = @wiki.page('test type a title here')
		assert_equal( 'tamc2', oldpage.author )
		assert_equal( 'hello world', oldpage.content )
	end
	
	def test_delete_page
		@wiki.revise('test delete','hello world','tamc2')
		page = @wiki.page('test delete')
		assert_equal('hello world', page.content )
		assert_equal( false, page.deleted? )
		@servlet.service( re = MockRequest[ :path => '/delete/test delete', :user => 'test user', :query => {} ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/TestDelete', rp[:redirect_destination] )
		assert_equal( 'test user', page.author )
		assert_equal('page deleted', page.content )
		assert_equal( true, page.deleted? )
	end
	
	def test_rollback_page
		0.upto(5) { |i| @wiki.revise('rollback test', i.to_s, 'test') }
		assert_equal( '5', @wiki.page('rollback test').textile )
		assert_equal( 'test', @wiki.page('rollback test').author )
		@servlet.service( re = MockRequest[ :path => '/rollback/rollback test', :user => 'rollbacker', :query => { 'revision' => 3 } ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/RollbackTest', rp[:redirect_destination] )
		assert_equal( '3', @wiki.page('rollback test').textile )
		assert_equal( 'rollbacker', @wiki.page('rollback test').author )
	end
	
	def test_upload
		filedata = MockFileData.new
		@servlet.service( re = MockRequest[ :path => '/upload/upload test', :user => 'uploader', :query => { 'file' => filedata, 'titleprefix' => 'upload ', 'newtitle' => 'test'} ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/UploadTest', rp[:redirect_destination] )
		page = @wiki.page('upload test')
		assert_equal( 'uploader', page.author )
		assert_equal( '/Attachment/testfile.txt', page.content )
	end
	
	def test_move_upload
		test_upload
		filedata = MockFileData.new
		@servlet.service( re = MockRequest[ :path => '/upload/upload test', :user => 'uploader2', :query => { 'file' => filedata, 'titleprefix' => 'upload ', 'newtitle' => 'second test'} ], rp = MockResponse.new )
		assert_equal( 'http://testsite.com/view/UploadSecondTest', rp[:redirect_destination] )
		newpage = @wiki.page('upload second test')
		assert_equal( 'uploader2', newpage.author )
		assert_equal( '/Attachment/testfile1.txt', newpage.content )
		oldpage = @wiki.page('upload test')
		assert_equal( 'uploader2', oldpage.author )
		assert_equal( 'content moved to [[upload second test]]', oldpage.content )
	end
	
end