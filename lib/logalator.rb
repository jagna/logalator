require 'rubygems'
require 'dm-core'
require 'model/request'

DataMapper.setup(:default, "postgres://#{ARGV[1]}:#{ARGV[2]}@localhost/logizator")
DataMapper.auto_upgrade!

if ARGV[0].nil? || !File.directory?(ARGV[0])
    puts "Give dir as an argument"
    exit  
end

line_re = /^(([\d\.])+)(\s\S+){2}\s\[(.*?)\]\s"((\S+)\s(\S+)\s(\S+))"\s(\d+|-)\s(\d+|-)\s"(.*?)"\s"(.+?)"$/
@robots = []
File.open('ignored_agents.txt').each_line { |r| @robots << Regexp.new(r.strip) unless "#" == r[0]}

def robot?(agent)
    @robots.any? { |robot| agent =~ robot }
end

done = File.open(File.join(ARGV[0], 'done_logs.txt'), "w+")
Dir.foreach(ARGV[0]) do |f|
   path = File.join(ARGV[0], f)
   next if !File.file?(path) && File.directory?(path) 
   i=0
   File.open(path, "r").each do |l|
       el = l.match(line_re)
       time = DateTime::parse("#{el[4]}".sub(/:/, ' ')) 
       u = User.first_or_create( :ip => el[1],:agent => el[12], :robot => robot?(el[12]) )
       h = Header.first_or_create( :method => el[6], :path => el[7], :protocol => el[8], :status => el[9], :bytes => el[10] )
       r = Request.create( :nr => i, :referrer => el[11], :date => time, :user => u, :header => h)
       if i % 25000 == 0
           print "\r#{f} #{i}"
           STDOUT.flush
       end
       i = i+1
   end
   puts
   done.puts("#{path} lines: #{i}")
end
done.close
