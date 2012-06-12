require 'test/unit'
require 'soks'

class TestSoks < Test::Unit::TestCase

	def test_version_number
		assert_match /^\d+\.\d+\.\d+$/, SOKS_VERSION
	end
end