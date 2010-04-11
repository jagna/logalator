require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'logalator/model/request'
require 'logalator/model/session'
require 'logalator/progressbar'
require 'suffix_tree'

DataMapper::Logger.new(STDOUT, :info)
DataMapper.setup(:default, "postgres://#{ARGV[0]}:#{ARGV[1]}@localhost/#{ARGV[2]}")
DataMapper.auto_upgrade!

def shring_content

end

si_co = SessionItem.count
puts "Session items #{si_co}"
DIVIDER = 10000
START=-1
LEAF=-2
CONTENT = "Content"
@pb = Console::ProgressBar.new("SessionItems", si_co/DIVIDER)
i=0
@stb = SuffixTreeBuilder.new
Session.all.each do |s|
    c_paths = {}#key - last element of path, value whole path 
    paths = []
    SessionItem.all(:session_id => s.id, :order => [:date, :nr]).each do |si|
        @pb.inc if (i+=1) % DIVIDER == 0
        if(si.session_item_id) #I as child
            c_paths[si.id] = []
            c_paths[si.id].replace (c_paths[si.session_item_id]) 
            c_paths[si.id] << si.page.name unless c_paths[si.id].last.eql?(CONTENT) && si.page.name.eql?(CONTENT)
        else #I as head
            c_paths[si.id] = []
            c_paths[si.id] << START
            c_paths[si.id] << si.page.name
        end
        if 0 == SessionItem.count(:session_id => s.id, :session_item_id => si.id)#I as a leaf
            c_paths[si.id] << LEAF
            paths << c_paths[si.id] 
        end
    end
    paths.each { |l| @stb << l; }
end
file = File.open("sub_paths_repetition_#{ARGV[2]}.txt", "w")
@stb.to_s_sort file
file.close unless file.closed?
@pb.finish
