require 'net/imap'

# From Dave Burt on comp.lang.ruby
class String
 def from_quoted_printable
   self.gsub(/\r\n/, "\n").gsub(/=(?![\dA-F]{2})/,'=3D').unpack("M").first
 end
end

class Message
	
	attr_reader :message_id, :subject, :sender_name, :sender_email, :date, :text

	def initialize( imap, message_id )
		@imap, @message_id = imap, message_id
		envelope = @imap.fetch( @message_id, 'ENVELOPE' ).first.attr['ENVELOPE']
		@subject = envelope['subject'].gsub(/^(Fw|Re):?/i,'').strip
		@sender_name = envelope['from'].first['name'].gsub(/@/,' at ')
		@date = envelope['date']
		@sender_email = envelope['from'].first['mailbox'] + ' at ' + envelope['from'].first['host']
		@sender_name = @sender_email unless @sender_name && @sender_name.size > 1
		@text = plain_text_content_from_message( message_id )
	end
	
	def plain_text_content_from_message( id )
		@imap.fetch( id, 'BODY[1]' ).first.attr['BODY[1]'].from_quoted_printable
	end

end

class Mail2WikiHelper

	DEFAULT_SETTINGS = {
		:server => 'imap.hermes.cam.ac.uk',
		:username => 'tamc2',
		:password => 'missing_a_password',
		:mailbox => 'test',
		:check_event => :hour,
		:subject_regexp => /.*/,
		:keyword => 'PutInWiki'
	}
	
	def initialize( wiki, settings = {} )
		@settings = DEFAULT_SETTINGS.merge( settings )
		@wiki = wiki
		check_mailbox
		@wiki.watch_for(@settings[:check_event]) { check_mailbox }
	end
	
	private
	
	def check_mailbox
		$LOG.info "Checking #{@settings[:mailbox]} on #{@settings[:server]}"
		login
		select_mailbox
		new_messages_for_wiki do |message_id|
			this_message = Message.new( @imap, message_id )
			if this_message.subject =~ @settings[:subject_regexp]
				$LOG.info "Adding '#{this_message.subject}' to wiki"
				add_message_to_wiki( this_message ) 
				mark_as_added( message_id )
			end
		end
		logout
	end
	
	def add_message_to_wiki( message )
		current_page = @wiki.page( message.subject )
		if current_page.empty?
			text = "h1. #{message.subject}"
		else
			text = current_page.textile
		end
		text << "\n\n"
		text << "*Copied from Email on #{message.date} from #{message.sender_name} (#{message.sender_email})*\n\n"
		text << "<pre>\n"
		text << message.text
		text << "\n</pre>\n"
		@wiki.revise(message.subject, text, message.sender_name )
	end
	
	def login
		@imap = Net::IMAP.new(@settings[:server])
		@imap.login( @settings[:username], @settings[:password] )
	end
	
	def logout
		@imap.logout
		@imap.disconnect
	end
	
	def select_mailbox
		@imap.select @settings[:mailbox]
	end
	
	def new_messages_for_wiki 
		@imap.search("UNKEYWORD #{@settings[:keyword]}").each { |id| yield id } 		
	end
	
	def mark_as_added( id )
		@imap.store( id, '+FLAGS', [@settings[:keyword]] )
	end
	
end