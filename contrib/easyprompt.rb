#require 'lafcadio'

# EasyPrompt is a utility for command-line scripts. It handles prompts and default values, and also provides a testing facility for mocking out the command-line user.
#
# For example, here's an irb session that illustrates what EasyPrompt does:
#
#   irb(main):001:0> require 'easyprompt'
#   => true
#   irb(main):002:0> prompt = EasyPrompt.new
#   => #<EasyPrompt:0x5a42a0 @stdout=#<EasyPrompt::MockableStdout:0x5a3e04>>
#   irb(main):003:0> fname = prompt.ask( "What's your first name?" )
#   What's your first name? John
#   => "John"
#   irb(main):004:0> lname = prompt.ask( "What's your last name?", "Doe" )
#   What's your last name? [Doe] 
#   => "Doe"
#   irb(main):005:0> correct = prompt.ask( "Is your name #{ fname } #{ lname }?", true, :boolean )
#   Is your name John Doe? [y] 
#   => true
#
# In the first example, we ask for the user's first name and get "John" as the response. In the second example, we supply the default of "Doe", which the user chooses by just pressing the "Enter" key. In the third example, we supply the default of +true+, which the user chooses as well. We received the boolean value +true+ as opposed to the string "true" or "y", because we specified <tt>:boolean</tt> as the +response_class+.
class EasyPrompt
	Version = '0.1.0'

	def initialize; @stdout =$stdout; end

	# Asks the user for input.
	# msg:: The prompt that tells the user what information to enter next.
	# default:: The default value that will be returned if the user enters a newline (usually by pressing "Enter") without typing any information. The default value will be displayed in square brackets after +msg+.
	# response_class:: The sort of value that EasyPrompt#ask should return. Valid response classes are:
	#                  [:string] This is the default.
	#                  [:boolean] Values will be turned into <tt>true</tt> or <tt>false</tt> depending on whether the user enters "y" or "n".
	def ask( msg, default = nil, response_class = :string )
		@stdout.write( prompt( msg, default, response_class ) + ' ' )
		stdin = $stdin
		response = stdin.gets
		response.chomp!
		if response == ''
			response = default
		else
			response = response =~ /^y/i if response_class == :boolean
		end
		response
	end
	
	def prompt( msg, default = nil, response_class = :string ) #:nodoc:
		prompt = msg
		unless default.nil?
			if response_class == :boolean
				default_str = default ? 'y' : 'n'
			else
				default_str = default.to_s
			end
			prompt += " [#{ default_str }]"
		end
		prompt
	end
end