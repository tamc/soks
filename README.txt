h1. SOKS: Another Ruby Wiki

******

IMPORTED TO GITHUB FOR POSTERITY. CODE HAS NOT BEEN MAINTAINED IN 7 YEARS

******


* This application is a Wiki (a system to allow the easy and collaborative editing of web pages).
* The project has been kindly hosted at http://rubyforge.org/projects/soks/
* The project wiki/home page is at http://www.soks.org

Quickstart:
# gem install Soks
# soks-create-wiki.rb
# http://localhost:8000

h2. REQUIRES

* Ruby 1.8.2
* A number of additional libraries are contained in contrib. 

h2. AUTHOR

* This software is copyright (c) Thomas Counsell 2004, 2005. tamc@rubyforge.org 
* It is licensed under the Ruby Licence, a liberal open source licence.  See LICENCE for more details.
* The author appreciates the code, suggestions and libraries provided by a buch of other people, see www.soks.org/author for individual acknowledgements.

h2. INSTALL

Preferably:
# Install rubygems from http://rubyforge.org/projects/rubygems/
# @gem install Soks@ (you may need to be root first)

Alternatively
# Download the tar or zip file from http://rubyforge.org/projects/soks/
# Unzip or untar it
# Change into the soks directory

h2. USE

execute @soks-create-wiki.rb@ (will be in your path if installed by gems, otherwise @./bin/soks-create-wiki.rb@ from the soks directory)
This will create a folder called soks-wiki in the current directory and launch the wiki.  Surfing to http://localhost:8000 to see it (it is initially accessible from localhost only)

To restart the wiki change into the soks-wiki directory and execute ruby start.rb

To change the settings (url, port, etc) edit the start.rb file in the soks-wiki directory.

h2. UPGRADE

If you already have a previous version of soks then to upgrade, run @soks-create-wiki.rb --destination-dir=path/to/your/wiki@ and it will guide you through the upgrade.

Note that if you were using the multi page index class before, you will need to manually delete all the old index pages (@rm content/Site%20Index*@).  The new pages will be created automatically.

h2. FEATURES

# Runs on its own webrick server (no independent web server required)
# Uses textile as its text coding (a proto-standard) 
# Uses a combination of flat and yaml files for storage (no database, and page content human readable outside of soks)
# Allows uploads
# Allows authentication
# Automatically links pages within the wiki
# Pages can be deleted and moved easily (and these can be undone)
# Has a mechanism for external classes to manipulate the wiki to provide, for instance, automatic calendar pages, or automatic summaries or blog like pages.

h2. BUGS

I suspect there are many, see http://www.soks.org/wiki/KnownBugs for details.

Tag: Include this page in the distribution
