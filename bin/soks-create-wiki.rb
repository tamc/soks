#!/usr/local/bin/ruby
require 'fileutils'
require 'erb'
require 'optparse'

def template_file_named( name )
	File.join($SOKS_APPLICATION_DIRECTORY,'templates',name)
end

# Used to create a new template
def copy_template( source, destination )
	unless File.exists?( template_file_named( source ) )
		puts "Couln't find template #{source} - aborting"
		exit
	end
	FileUtils.cp_r( template_file_named( source ),destination)
end

# Used to fill out the start script in the new template
def fill_out_script_template( script_directory, script_name, settings )
	script_template = ERB.new( IO.readlines( File.join( script_directory, script_name ) ).join )
	filled_out_script = script_template.result binding
	File.open( File.join( script_directory, script_name ), 'w' ) { |f| f.puts filled_out_script }
end

# Used to get the version number from a wiki
def version_number_from_wiki( directory )
	version_file = File.join( directory, 'version.txt')
	return nil unless File.exists?( version_file )
	IO.readlines( version_file )[0].strip # The first line of version.txt should contain the number
end 

# Used to backup a wiki directory
def backup_directory( directory )
	backup_dir = directory+'-bak-0'
	while File.exists?(backup_dir); backup_dir.succ!; end
	FileUtils.mv(directory, backup_dir)
	backup_dir
end

# Used to remove the content of a directory (FileUtils.rm_r seems to fail for me?)
def remove_directory( directory )
	Dir.entries(directory).each do |file|
		next if File.directory?( file )
		File.delete( File.join( directory, file ) )
	end
	Dir.rmdir( directory )
end

#Find where we are
$SOKS_APPLICATION_DIRECTORY, this_script =  File.split(File.expand_path(File.dirname(__FILE__)))

#Make sure we can find our libraries
soks_library = [ File.join( $SOKS_APPLICATION_DIRECTORY,'lib') , File.join( $SOKS_APPLICATION_DIRECTORY,'lib','helpers'), File.join( $SOKS_APPLICATION_DIRECTORY,'/contrib' ) ]
$:.push( *soks_library )

require 'easyprompt'

#Default options
interactive = true
create = true
start = true
upgrade = true
destination = 'soks-wiki'
source = 'default'
url = 'http://localhost:8000'
port = nil

#Command line switches
opts = OptionParser.new
opts.on('--no-interaction', FalseClass, "Do not prompt you for any information") { |val| interactive = val }
opts.on('--no-create', FalseClass, "Do not create a new wiki if one does not exist") { |val| create = val }
opts.on('--no-start', FalseClass, "Do not start the wiki") { |val| start = val }
opts.on('--no-upgrade', FalseClass, "Do not upgrade the wiki if it is from a previous version") { |val| upgrade = val }

opts.on("--template #{source}", String, "The name of the template to base the wiki on") { |val| source = val }
opts.on("--destination-dir #{destination}", String, "The folder for this wiki") { |val| destination = val }
opts.on("--url #{url}", String, "The url that a new wiki will use") { |val| url = val }
opts.on("--port #{url[/:(\d+)$/,1] || 80}", Integer, "The port a new wiki will use if not the same as in the url") { |val| port = val }

#Update the options based on the command line
opts.parse(*ARGV)
port ||= url[/:(\d+)$/,1] || 80

prompt = EasyPrompt.new

#Create a new wiki from a template if required
if create && !File.exists?( destination)
	if interactive
		exit unless prompt.ask("No wiki found at #{destination}. Create a new one?",true,:boolean)
		destination = prompt.ask("What folder should I put the wiki in?",destination)
		source = prompt.ask("Which template should I use to create the wiki?",source)
		url = prompt.ask("What url will this wiki be accessed from (include the port)?",url)
		port = prompt.ask("What port will this wiki be accessed from?", port )
	end
	puts "Creating wiki at #{destination} from #{source}"
	copy_template( source, destination )
	fill_out_script_template( destination, 'start.rb', { :root_directory => File.expand_path( destination ), :soks_libraries => soks_library, :url => url, :port => port, :version => version_number_from_wiki( destination )  } )
end

if upgrade
	wiki_version = version_number_from_wiki( destination ) || prompt.ask('Cant find a version number, please enter what version this soks is','0.0.2')
	soks_version = version_number_from_wiki( template_file_named( source ) )
	if wiki_version != soks_version
		
		keep_content = true
		keep_uploads = true
		keep_stylesheet_etc = false
		keep_views = false
		
		if interactive
			exit unless prompt.ask("This wiki uses version #{wiki_version} of soks.\nSoks is currently on version #{soks_version}.\nShould I try and upgrade this wiki to #{soks_version}?",true,:boolean)
			keep_content = prompt.ask("Should I keep your content?", keep_content, :boolean )
			keep_uploads = prompt.ask("Should I keep your uploads?", keep_uploads, :boolean )
			keep_views = prompt.ask("Should I keep your views?", keep_views, :boolean )
			keep_stylesheet_etc = prompt.ask("Should I keep your logo and stylesheet?", keep_stylesheet_etc, :boolean )
		end
			
		old_wiki = backup_directory( destination )
		puts "Backed up wiki to #{old_wiki}"
		
		copy_template( source, destination )
		puts "Copied #{source} to #{destination}"
		
		if keep_content
			remove_directory( File.join( destination, 'content' ) )
			FileUtils.cp_r( File.join( old_wiki, 'content'), destination )
			puts "Copied content from #{old_wiki} to #{destination}"
			if wiki_version == '0.0.2'
				require 'soks-upgrade-0.0.2'
				SoksUpgrade.new.upgrade_revisions( destination )
				SoksUpgrade.new.upgrade_content( destination )
			end
		else
			puts "Replaced old content with default"
		end
		
		if keep_uploads
			FileUtils.cp_r( File.join( old_wiki, 'attachment'), destination )
			puts "Copied uploads from #{old_wiki} to #{destination}"
		else
			puts "Replaced old uploads with default"
		end
		
		unless keep_stylesheet_etc
			# Pretty unelegant to copy this back again, better ideas?
			FileUtils.cp_r( File.join( template_file_named( source ), 'attachment'), destination )
			puts "Upgraded stylesheets, logo and the like"
		else
			puts "Copied stylesheets, logo and the like from #{old_wiki} to #{destination}"
		end
		
		if keep_views
			FileUtils.cp_r( File.join( old_wiki, 'views'), destination )
			puts "Copied views from #{old_wiki} to #{destination}"
		else
			puts "Upgrade views"
		end
		
		old_start = IO.readlines( File.join(old_wiki,'start.rb')).join
		
		case wiki_version
		when '0.0.0'..'0.9.9'
			old_url = old_start[/:url\s*=>\s*('|")(.*?)('|"),/,2]
			old_port = old_start[/:port\s*=>\s*(\d*),/,1]
		else
			old_url = old_start[/View\.new\(.*?,\s*('|")(.*?)('|")\s*,/i,2]
			old_port = old_start[/:port\s*=>\s*(\d*)/i,1]	
		end
		
		if interactive
			old_url = prompt.ask("What url will this wiki be accessed from (include the port)?",old_url) 
			old_port = prompt.ask("What port will this wiki be accessed from?",old_port )
		end
		
		fill_out_script_template( destination, 'start.rb', { :root_directory => File.expand_path( destination ), :soks_libraries => soks_library, :url => old_url, :port => old_port, :version => version_number_from_wiki( destination ) } )
		
		puts "\nI'm very sorry, but if you modified the authenticators, or added any AutomaticSummaries or AutomaticCalendars or suchlike, then you will need to copy them across manually from #{old_wiki}/start.rb to #{destination}/start.rb.\n Note that their api may have changed, so please look at the examples in #{destination}/start.rb\n\nOnce you have done that, run ruby #{destination}/start.rb to start."
		exit
	end
end

#Start the wiki if required
script = File.join( destination, 'start.rb' )
if start && File.exists?( script )
	if interactive
		exit unless prompt.ask("Start #{destination} on #{url}?",true,:boolean)
	end
	puts "Starting #{destination} on #{url}"
	require script
end