require 'rubygems'

if ARGV[0].nil? || !File.directory?(ARGV[0])
    puts "Give dir as an argument"
    puts "#{$PROGRAM_NAME} logs_directory connection_string"
    exit  
end 

require 'dm-core'
require 'logalator/model/request'
require 'logalator/progressbar'

DataMapper.setup(:default, "postgres://#{ARGV[1]}:#{ARGV[2]}@localhost/#{ARGV[3]}")
DataMapper.auto_upgrade!

line_re = /^(([\d\.])+)(\s\S+){2}\s\[(.*?)\]\s"((\S+)\s(\S+)\s(\S+))"\s(\d+|-)\s(\d+|-)\s"(.*?)"\s"(.+?)"$/
@robots = []
File.open('logalator/ignored_agents.txt').each_line { |r| @robots << Regexp.new(r.strip) unless "#" == r[0]}

def robot?(agent)
    @robots.any? { |robot| agent =~ robot }
end

DIVIDER = 10000
done = File.open(File.join(ARGV[0], 'done_logs.txt'), "w+")
Dir.foreach(ARGV[0]) do |f|
   path = File.join(ARGV[0], f)
   next if !File.file?(path) && File.directory?(path) 
   #posix system required
   lines = `wc -l #{path}`.to_i
   pb = Console::ProgressBar.new("#{f}", lines/DIVIDER)
   Request.transaction do |t|
    i=0
    File.open(path, "r").each do |l|
       el = l.match(line_re)
       time = DateTime::parse("#{el[4]}".sub(/:/, ' ')) 
       u = User.first_or_create( :ip => el[1],:agent => el[12], :robot => robot?(el[12]) )
       h = Header.first_or_create( :method => el[6], :path => el[7], :protocol => el[8], :status => el[9], :bytes => el[10] )
       r = Request.create( :nr => i, :referrer => el[11], :date => time, :user => u, :header => h)
       if i % DIVIDER == 0
           pb.inc
       end
       i = i+1
    end #file
    pb.finish
    puts
    done.puts("#{path} lines: #{i}")
   end #transaction
end
done.close
