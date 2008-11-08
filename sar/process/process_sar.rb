#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'optparse/time'
require 'ostruct'
#use sys-uname gem to get local system's name
require 'sys/uname'
require 'date'

require 'pp'

#option parsing
def parse_opts(args)
	# The options specified on the command line will be collected in *options*.
	# We set default values here.
	options = OpenStruct.new
	options.date_format = "m/d/Y"
	options.time_format = "h:m:s p"
	options.system = Sys::Uname.nodename
        options.delimiter = "|"
	
	opts = OptionParser.new do |opts|
		opts.banner = "Usage: example.rb [options]"
		
		opts.separator ""
		opts.separator "Input parser options:"
		
		# Mandatory arguments.
		opts.separator ""
		opts.on("-d", "--date_format DATE_FORMAT",
			"Use DATE_FORMAT as date format for parsing dates in input",
			"Valid characters are:",
			"	Y: year on 4 digits",
			"	y: year on 2 digits",
			"	m: month",
			"	d: day of month",
			"All other characters are treated as-is",
                        "Default: \"" + options.date_format + "\"") do |df|
			options.date_format = df
		end
		
		opts.separator ""
		opts.on("-t", "--time_format TIME_FORMAT",
			"Use TIME_FORMAT as time format for parsing time in input",
			"Valid characters are:",
			"	h: hour",
			"	m: minute",
			"	s: second",
			"	p: AM/PM indicator",
			"All other characters are treated as-is",
                        "Default: \"" + options.time_format + "\""
                        ) do |tf|
			options.time_format = tf
		end
		
		opts.separator ""
		opts.on("-s","--system SYSTEM_NAME",
                        "Name of system from which we have sar data",
                        "Default: name of this system (\"" + options.system + "\")") do |sys|
			options.system = sys
		end
                
		opts.separator ""
		opts.separator "Output options:"

		opts.separator ""
                opts.on("-D", "--delimiter DELIMITER",
                        "Use DELIMITER as delimiter in output file",
                        "Default: \"" + options.delimiter + "\"") do |del|
                        options.delimiter = del
                end
                      
		
		opts.separator ""
		opts.separator "Common options:"
		
		# No argument, shows at tail.  This will print an options summary.
		# Try it and see!
		opts.separator ""
		opts.on_tail("-h", "--help", "Show this message") do
		  puts opts
		  exit
		end
	end
	
	opts.parse!(args)
	options
end  # parse_opts

def set_global_opts(opts)
	options = OpenStruct.new
	#regexps to find date and time fields
	df = Regexp.escape(opts.date_format).gsub(/[md]/,'\d{1,2}').gsub(/Y/,'\d{4,4}').gsub(/y/,'\d{2,2}')
	tf = Regexp.escape(opts.time_format).gsub(/[hms]/,'\d{1,2}').gsub(/p/,'[ap]m')
	
	#lines ending with a date are headers
	options.header_rxp = Regexp.new('(' + df + ')',Regexp::IGNORECASE)
	#lines starting with a timestamp are data
	options.time_rxp = Regexp.new('^\s?(' + tf + ')',Regexp::IGNORECASE)
	options.date_format = opts.date_format.gsub(/([yYmd])/,'%\1')
	options.time_format = opts.time_format.gsub(/h/, /p/ =~ opts.time_format ? '%I' : '%H').gsub(/m/,'%M').gsub(/s/,'%S').gsub(/p/,'%p')
	options.system_name = opts.system
        options.delimiter = opts.delimiter
	options
end # set_global_opts

#classify a single line from the input
def classify(line)
	case line
	when @global_opts.header_rxp then :header
	when @global_opts.time_rxp then :data_with_time
	when /^\s{2,}\S/ then :data_without_time #there are data lines that don't have a timestamp at front
	else :unknown
	end
end #classify

#output the results
def output_data(data_tab)
	#first element of data table containts header info
	header = data_tab[0]
	#all the other elements are mesaurements
	data = data_tab[1..data_tab.length-1]
	return if data.empty?
	#does the data_line contain a device id? Like for cpu utilization for single processors
	has_unit = data.reject{|data_line| data_line.length >= 3 and  /^\d+(.\d+)?$/ =~ data_line[2]}.length > 0
	unit_type = has_unit ? header[2] : '' 
	data.each do |data_line|
		date = data_line[0]
		time = data_line[1]
		unit_name = has_unit ? data_line[2] : ''
		#collect measurement name and measurement value
		[header[(has_unit ? 3 : 2)..(data_line.length-1)], data_line[(has_unit ? 3 : 2)..(data_line.length-1)]].transpose.each do |meas|
			puts [@global_opts.system_name, %Q{#{date.strftime("%Y.%m.%d")} #{time.strftime("%H:%M:%S")}}, unit_type, unit_name, meas].flatten.join(@global_opts.delimiter)
		end
	end
end #output_data

#process a single file
def process_file(file)
	#datafile starts with header containing date if it does not then we use today's date
	date = Date.today
	time = nil
	#are we inside a data table?
	in_data = false
	data_tab = []
	file.readlines.each do |line|
		line = line.chomp
		lclass = classify(line)
		data_tab = [] unless in_data
		case lclass
		when :header
			#file header
			date = DateTime.strptime(@global_opts.header_rxp.match(line)[1],@global_opts.date_format)
			in_data = false
			time = nil
		when :data_with_time then
			in_data = true
			time = DateTime.strptime(@global_opts.time_rxp.match(line)[1],@global_opts.time_format)
			data = [date, time] + line.gsub(@global_opts.time_rxp,'').split
			data_tab << data
		when :data_without_time then
			if in_data then
				data = [date, time] + line.gsub(@global_opts.time_rxp,'').split
				data_tab << data
			end
		else
			in_data = false
			time = nil
		end
		#we output the collected data if we've finished with the current chunk
		output_data(data_tab) unless in_data or data_tab.empty?  
	end
	output_data(data_tab) if not data_tab.empty? and in_data
end

options = parse_opts(ARGV)

@global_opts = set_global_opts(options)

#we use files from the remaining arguments
files=ARGV.map{|arg|
	begin
		File.new(arg)
	rescue
		$stderr.puts(%Q{File #{arg} not found})
		nil
	end
}.reject{|file| 
	file.nil?
}

#if we don't get a filename we use stdin instead
files=[$stdin] if ARGV.empty?

files.each do |file|
	process_file(file)
	file.close unless file === $stdin
end

