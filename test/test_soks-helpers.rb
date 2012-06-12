require 'test/unit'
require 'fileutils'
require 'mock-objects'
require 'helpers/default-helpers'
require 'generator'

class TestAutomaticSummary < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_basics
		AutomaticSummary.new( @wiki, 'automatic summary' ) { |page| page.name =~ /hello/i }
		@wiki.revise 'hello world', 'hello world', 'test author'
		@wiki.revise 'hello john', 'hello john', 'test author'
		@wiki.revise 'hello frank', 'hello frank', 'test author'
		@wiki.revise 'hello frank', 'page deleted', 'test author'
		@wiki.revise 'goodbye world', 'goodbye world', 'test author'
		wait_for_queue_to_empty
		content = @wiki.page('automatic summary').content
		assert_match /hello world/, content
		assert_match /hello john/, content
		assert_no_match /goodbye world/, content
		assert_no_match /hello frank/, content
	end
	
	def test_updates_on_revision
		as = AutomaticSummary.new( @wiki, 'update on revision test' ) { |page| page.name =~ /summarise/i }
		@wiki.revise('summarise 1','initial content','test author')
		wait_for_queue_to_empty
		assert_match(/initial content/,@wiki.page('update on revision test').content )
		@wiki.revise('summarise 1','updated content','test author')
		wait_for_queue_to_empty
		assert_match(/updated content/,@wiki.page('update on revision test').content )
	end

	def test_removes_when_no_longer_true
		AutomaticSummary.new( @wiki, 'remove when not true test' ) { |page| page.content =~ /hello/i }
		@wiki.revise('summarise 1','hello','test author')
		wait_for_queue_to_empty
		assert_match(/hello/,@wiki.page('remove when not true test').content )
		@wiki.revise('summarise 1','bye','test author')
		wait_for_queue_to_empty
		assert_no_match(/hello/,@wiki.page('remove when not true test').content )
		assert_no_match(/bye/,@wiki.page('remove when not true test').content )
	end

end

class TestRecentChanges < Test::Unit::TestCase
	include TearDownableWiki
	
	def test_detect_change
		rc = AutomaticRecentChanges.new( @wiki)
		@wiki.revise( 'testpage','B','normal person')
		@wiki.revise( 'testpage2','A','normal person')
		wait_for_queue_to_empty
		assert_equal(2, rc.summary.to_a.size)
		assert_match( /normal person/i, rctextile )
	end
	
	def test_merge_author_change
		rc = AutomaticRecentChanges.new( @wiki)
		@wiki.revise( 'testpage','B','normal person')
		@wiki.revise( 'testpage','A','normal person')
		wait_for_queue_to_empty
		assert_equal(1, rc.summary.to_a.size)
		assert_match( /normal person/i, rctextile )
	end
	
	def test_dont_merge_different_authors_change
		@rc = AutomaticRecentChanges.new( @wiki)
		@wiki.revise( 'testpage','B','p1')
		@wiki.revise( 'testpage','A','p2')
		wait_for_queue_to_empty
		assert_equal(2, @rc.summary.to_a.size)
		assert_match( /p1/i, rctextile )
		assert_match( /p2/i, rctextile )
	end
	
	def test_exclude_helpers_initially
		@wiki.revise( 'testpage','B','normal person')
		@wiki.revise( 'testpage2','content moved from','AutomaticPageMover')
		@wiki.revise( 'testpage2','A','normal person')
		rc = AutomaticRecentChanges.new( @wiki)
		assert_equal(['recent changes to this site','testpage','testpage2'],@wiki.map{|name,page| name }.sort)
		assert_equal(2, rc.summary.to_a.size)
		assert_match( /normal person/i, rctextile )
		assert_no_match( /AutomaticPageMover/i, rctextile )
	end
	
	def test_exclude_helpers_later
		rc = AutomaticRecentChanges.new( @wiki)
		@wiki.revise( 'testpage','B','normal person')
		@wiki.revise( 'testpage2','content moved from','AutomaticPageMover')
		@wiki.revise( 'testpage2','A','normal person')
		wait_for_queue_to_empty
		assert_equal(['recent changes to this site','testpage','testpage2'],@wiki.map{|name,page| name }.sort)
		assert_equal(2, rc.summary.to_a.size)
		assert_match( /normal person/i, rctextile )
		assert_no_match( /AutomaticPageMover/i, rctextile )
	end
	
	def test_change_in_page_capitalisation
		rc = AutomaticRecentChanges.new( @wiki)
		@wiki.revise( 'testpage','B','normal person')
		wait_for_queue_to_empty
		assert_match( /\[\[testpage\]\]/, rctextile )
		assert_no_match( /\[\[TestPage\]\]/, rctextile )
		@wiki.revise( 'TestPage','C','normal person')
		wait_for_queue_to_empty
		assert_match( /\[\[TestPage\]\]/, rctextile )
		assert_equal( 1, count_matches(  /\[\[TestPage\]\]/ ) )
	end
	
	private
	
	def count_matches( regexp )
		count = 0
		rctextile.gsub( regexp ) { |m| count += 1 }
		count
	end
	
	def rctextile
		@wiki.page("Recent Changes to This Site").textile 
	end	
end

class TestCalendar < Test::Unit::TestCase
	include TearDownableWiki
	
	def setup
		super
		AutomaticCalendar.new( @wiki )
		AutomaticUpdateCrossLinks.new( @wiki, @view )
	end
	
	def test_2006_Mar_html
		wait_for_queue_to_empty
		page = @wiki.page('2006 Mar')
		desired_html = IO.readlines('test/html/2006Mar.html')
		actual_html = @view.redcloth( page ).split("\n").map { |l| "#{l}\n" }
		SyncEnumerator.new(desired_html,actual_html).each do |desired,actual|
			assert_equal( desired, actual )
		end
	end 
end