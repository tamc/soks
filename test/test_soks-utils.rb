require 'test/unit'
require 'soks-utils'
require 'fileutils'

class ToTimeUnitsMT < Test::Unit::TestCase

	def test_seconds
		assert_equal( 'fraction of a second', 0.4.to_time_units )
		assert_equal( 'second', 0.8.to_time_units )
		assert_equal( 'second', 1.3.to_time_units )
		assert_equal( '5 seconds', 5.to_time_units )
	end

	def test_minutes
		assert_equal( 'minute',     46.to_time_units )
		assert_equal( '10 minutes', (60*10.4).to_time_units )
	end

	def test_hours
		assert_equal( 'hour',    (60*60*1.2).to_time_units )
		assert_equal( '2 hours', (60*60*1.8).to_time_units )
	end

	def test_days
		assert_equal( 'day',     (60*60*24*0.95).to_time_units )
		assert_equal( '20 days', (60*60*24*20).to_time_units )
	end

	def test_months
		assert_equal( 'month',     (60*60*24*30*1.1).to_time_units )
		assert_equal( '10 months', (60*60*24*30*10).to_time_units )
	end

	def test_years
		assert_equal( 'year',     (60*60*24*30*14).to_time_units )
		assert_equal( '11 years', (60*60*24*365*11).to_time_units )
	end
end

class TimeSameDayTest < Test::Unit::TestCase
	
	def test_simple
		other_day = Time.local(2005,04,01,9,30)
		assert( other_day.same_day?( Time.local(2005,04,01,23,59) ) )
		assert( other_day.same_day?( Time.local(2005,04,01,0,0) ) )
	end
	
	def test_not_match
		other_day = Time.local(2005,04,01,9,30)
		assert_equal( false, other_day.same_day?( Time.local(2004,04,02,9,30) ) )
		assert_equal( false, other_day.same_day?( Time.local(2004,03,01,9,30) ) )
		assert_equal( false, other_day.same_day?( Time.local(2003,04,01,9,30) ) )	
	end
end

#class StringToValidPageNameTest < Test::Unit::TestCase
#	
#	def test_punctuation
#		assert_equal( 'abcdefghijklm', 'a/b\\c[d]e?f{g}h&i^j`k<l>m'.to_valid_pagename )
#	end
#	
#	def test_trailing_space
#		assert_equal( 'abcdefghijklm', ' abcdefghijklm '.to_valid_pagename )
#	end
#end

class FileUniqueFilenameTest < Test::Unit::TestCase
	include FileUtils
	
	def teardown
		rmtree( folder )
	end

	def test_no_collision
		assert_equal( 'ok.txt', File.unique_filename( folder, 'ok.txt' ) )
		create_file 'ok.jpg', ''
		assert_equal( 'ok.txt', File.unique_filename( folder, 'ok.txt' ) ) 
	end
	
	def test_whitespace
		assert_equal( 'ok.txt', File.unique_filename( folder, 'o k.txt' ) )
	end

	def test_collision
		assert_equal( 'ok.txt', File.unique_filename( folder, 'ok.txt' ) )
		create_file 'ok.txt', ''
		assert_equal( 'ok1.txt', File.unique_filename( folder, 'ok.txt' ) )
	end
	
	def test_numbered_collision
		assert_equal( 'ok1.txt', File.unique_filename( folder, 'ok1.txt' ) )
		create_file 'ok1.txt', ''
		assert_equal( 'ok11.txt', File.unique_filename( folder, 'ok1.txt' ) )
	end

	def test_high_number_collision
		create_file 'ok.txt', ''
		1.upto( 9 ) { |n| create_file "ok#{n}.txt", '' }
		assert_equal( 'ok10.txt', File.unique_filename( folder, 'ok.txt' ) )
	end

	private
	
	def create_file( name, content )
		File.open( File.join( folder, name ), 'w') { |f| f.puts content }
	end
	
	def files
		Dir.entries( folder ).delete_if { |name| name =~ /^\.+$/ }
	end
	
	def folder
		@folder ||= make_folder
	end
	
	def make_folder
		mkdir( 'testcontent' )
		'testcontent'
	end

end

class TimeNextText < Test::Unit::TestCase

	def test_next_second
		assert_equal( Time.local(2004,12,31,23,0,1), Time.local(2004,12,31,23,0,0).next(:sec) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23,59,59).next(:sec) )
	end

	def test_next_minute
		assert_equal( Time.local(2004,12,31,23,1), Time.local(2004,12,31,23,0).next(:min) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23,59).next(:min) )
	end

	def test_next_hour
		assert_equal( Time.local(2004,12,31,23,0), Time.local(2004,12,31,22,59).next(:hour) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23).next(:hour) )
	end
	
	def test_next_day
		assert_equal( Time.local(2004,12,31,0,0), Time.local(2004,12,30,22,00).next(:day) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23).next(:day) )
	end
	
	def test_next_month
		assert_equal( Time.local(2004,12), Time.local(2004,11,30,22,00).next(:month) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23).next(:month) )
		assert_equal( Time.local(2005,2,1), Time.local(2005,1,31).next(:month) )
		assert_equal( Time.local(2005,2), Time.local(2005,1).next(:month) )
	end
	
	def test_next_year
		assert_equal( Time.local(2005), Time.local(2004,11,30,22,00).next(:year) )
		assert_equal( Time.local(2005,1,1), Time.local(2004,12,31,23).next(:year) )
		assert_equal( Time.local(2006), Time.local(2005).next(:year) )
	end
	
end

class DaysFromTest < Test::Unit::TestCase
	
	def test_days_from
		t1 = Time.local( 2005,01,01,19,27)
		assert_equal(0, t1.days_from( t1 ) )
		assert_equal(-1, t1.days_from( Time.local( 2005,01,02 ) ) )
		assert_equal(1, t1.days_from( Time.local( 2004,12,31 ) ) )
	end
	
end

class RelativeDayTest < Test::Unit::TestCase
	
	def test_today
		assert_equal("Today", Time.now.relative_day )
	end
	
	def test_yesterday
		assert_equal(-1, (Time.now-24*60*60).days_from( Time.now ) )
		assert_equal("Yesterday", (Time.now-24*60*60).relative_day)
	end
	
	def test_some_time_ago
		some_time_ago = Time.now - (10*24*60*60)
		assert_equal(some_time_ago.strftime('%d %b'), some_time_ago.relative_day)
	end
	
	def test_long_time_ago
		some_time_ago = Time.now - (400*24*60*60)
		assert_equal(some_time_ago.strftime('%d %b %Y'), some_time_ago.relative_day)
	end
	
end

class PeriodicNotificationTest < Test::Unit::TestCase
 	
 	def test_seconds
 		time_at_last_call = Time.now
 		total_time_between_calls = 0
 		total_number_of_calls = 0
 		PeriodicNotification.new(:second) do |period|
 			total_time_between_calls = total_time_between_calls + (Time.now - time_at_last_call)
 			time_at_last_call = Time.now
 			total_number_of_calls += 1
 		end
 		sleep( 3 )
 		assert_equal( 3, total_number_of_calls )
 		assert_equal( 1, (total_time_between_calls/total_number_of_calls).round )
 	end
 	
 end
 
 class StringDiffsTest < Test::Unit::TestCase
 	
 	def test_simple
 		version_one = "A\nB\nC\n"
 		version_two = "A\nC\nC\n"
 		assert_equal( [[['-',1,'B'],['+',1,'C']]], version_two.changes_from( version_one ) )
 	end
 
 end