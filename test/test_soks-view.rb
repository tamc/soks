require 'test/unit'
require 'fileutils'
require 'mock-objects' 
require 'generator' 

class TestBruteMatch < Test::Unit::TestCase

	def setup
		@match = BruteMatch.new
		@match['one'] = :one
		@match['two'] = :two
		@match['one two'] = :one_two
		@match['two three'] = :two_three
		@match['three: four'] = :three_colon_four
		@match['2005 Mar'] = :a_date
		@match["l'equipe"] = :the_team
		@match["Site Index" ] = :index
		@match["Site Index A."] = :index_a
		@match[".Site Index A."] = :dot_index_a		
	end
	
	def test_basic
		assert_equal( [['three: four',:three_colon_four],['two',:two]], match('two three: four or more') )
	end
	
	def test_case
		assert_equal( [['One',:one]] , match('One') )
	end
	
	def test_length
		assert_equal( [['one two',:one_two]], match("a one two\nthree four") )
		assert_equal( [['two three',:two_three],['one',:one]], match('a one two three four') )
	end
	
	def test_fullwords
		assert_equal( [['two',:two]], match('aone two!') )
		assert_equal( [['two three',:two_three]], match('two three: fourormore') )
	end
	
	def test_number_match
		assert_equal( [['2005 Mar',:a_date]], match('forward to 2005 Mar >') )
	end
	
	def test_single_quote
		assert_equal( [["L'EQUIPE",:the_team]], match("Oh! L'EQUIPE? C'est...") )
	end
	
	def test_index
		assert_equal( :index_a, @match['site index a.'])
		assert_equal( [['Site Index',:index]],match("Site Index B. ball") )
		assert_equal( [['Site Index A.',:index_a]],match("Site Index A. ball") )
		assert_equal( [['.Site Index A.',:dot_index_a]],match(".Site Index A. ball") )
	end
	
	def test_do_not_match
		assert_equal [], match("Oh! L'EQUIPE? C'est...", ["l'equipe"])
	end
	
	def match( text, do_not_match = [] )
		matches = []
		@match.match( text, do_not_match ) { |m,p| 
			matches << [m,p]
			"$1"
		}
		matches
	end	
end

class TestView < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_url_name_for_page_name
		assert_equal('Testpage', @view.url_name_for_page_name('TestPage'))
		assert_equal('APageWithPunctuation', @view.url_name_for_page_name('a, page! \'with PuNcTuation?'))
		assert_equal('APageWithPunctuation-2', @view.url_name_for_page_name('!a, page! \'with PuNcTuation'))
		assert_equal('APageWithPunctuation-3', @view.url_name_for_page_name('.a, page! \'with PuNcTuation'))
		assert_equal("PunctuationOnlyInTitle",	@view.url_name_for_page_name('!!!'))
	end
	
	def test_page_name_for_url_name
		assert_equal('UnknownPage', @view.page_name_for_url_name('UnknownPage'))
		assert_equal('Unknown Page!', @view.page_name_for_url_name('Unknown Page!'))
		@wiki.revise('Unknown Page!','hello world','urltest')
		@wiki.revise('Unknown Page?','hello world','urltest')
		assert_equal('Unknown Page!', @view.page_name_for_url_name('UnknownPage'))
		assert_equal('Unknown Page?', @view.page_name_for_url_name('UnknownPage-2'))
	end
	
	def test_moved_page_name_for_url_name
		@wiki.revise('capital page','stuff','test')
		assert_equal('capital page', @view.page_name_for_url_name('CapitalPage'))
		@wiki.move('capital page','Capital Page','test')
		assert_equal('Capital Page', @view.page_name_for_url_name('CapitalPage'))
	end
	
	def test_render
		@wiki.revise('test view','hello world','tamc2')
		assert_equal('hello world', @wiki.page('test view').content )
		assert_match( /<p>hello world<\/p>/, @view.render( 'test view' ) )
	end
end

class TestErbHelper < Test::Unit::TestCase
	include TearDownableWiki

	def test_url
		assert_equal( 'http://testsite.com/view/HomePage', @view.url( 'home page' ) )
		assert_equal( 'http://testsite.com/edit/HomePage', @view.url( 'home page','edit' ) )
		assert_equal( 'http://testsite.com/view/LHomePage', @view.url( "l'home page" ) )
		assert_equal( 'http://testsite.com/view/LHomePage-2', @view.url( "l'home page?" ) )
	end
end

class TestPagesTextile < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_page
		page = Page.new('test page')
		page.revise('hello world!','test_person')
		assert_equal('hello world!', page.textile )
	end
	
	def test_image_page
		page = ImagePage.new('test image page')
		page.revise('/attached/hello.jpg','test_person')
		assert_equal('!http://testsite.com/attached/hello.jpg!:http://testsite.com/view/TestImagePage', page.textile(@view) )	
	end
	
	def test_attachment_page
		page = AttachmentPage.new('test attachment page')
		page.revise('/attached/hello.jpg','test_person')
		assert_equal("[[ test attachment page => http://testsite.com/attached/hello.jpg ]]\n", page.textile(@view) )
	end
end

class TestWikiRedCloth < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		AutomaticUpdateCrossLinks.new( @wiki, @view )
	end
	
	def test_basics
		@view.revise( 'textile basics', IO.readlines('test/html/Poignant.textile').join, '_why' )
		wait_for_queue_to_empty
		page = @wiki.page('textile basics')
		desired_html = IO.readlines('test/html/Poignant.html').join.gsub( /\n+/, "\n" )
		actual_html = @view.redcloth( page ).gsub( /\n+/, "\n" )
		SyncEnumerator.new(desired_html,actual_html).each do |desired,actual|
			assert_equal( desired, actual )
		end
	end
	
	def test_apostrophe_in_title
		@view.revise("L'equipe",'a test page','tamc2')
		@view.revise('test apostrophe',"go L'equipe!",'tamc2')
		wait_for_queue_to_empty
		assert_equal("<p>go <a href='http://testsite.com/view/LEquipe' class='automatic'>L'equipe</a>!</p>",html('test apostrophe'))
	end
	
	def test_quotes_in_title
		@view.revise('A "great page" of stuff','a test page','tamc2')
		@view.revise('test quotes in title','A "great page" of stuff','tamc2')
		wait_for_queue_to_empty
		assert_equal( %q{<p><a href='http://testsite.com/view/AGreatPageOfStuff' class='automatic'>A "great page" of stuff</a></p>},html('test quotes in title'))
	end
	
	def test_dont_match_the_page_title
		@view.revise('Ruby','a page about ruby','tamc2')
		@view.revise('not ruby','a page about ruby','tamc2')
		wait_for_queue_to_empty
		assert_equal( %q{<p>a page about <a href='http://testsite.com/view/Ruby' class='automatic'>ruby</a></p>},html('not ruby'))
		assert_equal( %q{<p>a page about ruby</p>},html('ruby'))
	end
	
	def test_wiki_links
		@view.revise('test1','[[test => a wonderfull page?great=good ]]','tamc2')
		@view.revise('test2','[[test => /edit/a wonderfull page?great =good ]]','tamc2')
		@view.revise('test3','[[test => /revision/a wonderfull page?great=good?revision=1 ]]','tamc2')
		wait_for_queue_to_empty
		assert_equal( %q{<a href='http://testsite.com/view/AWonderfullPageGreatGood' class='missing'>test</a>},html('test1'))
		assert_equal( %q{<a href='http://testsite.com/edit/AWonderfullPageGreatGood-2' class='missing'>test</a>},html('test2'))
		assert_equal( %q{<a href='http://testsite.com/revision/AWonderfullPageGreatGood?revision=1' class='missing'>test</a>},html('test3'))
	end
	
	private
	
	def html( page_name )
		@view.redcloth(@view.page(page_name))
	end
	
end