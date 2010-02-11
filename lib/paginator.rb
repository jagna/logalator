require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'logalator/model/request'
require 'logalator/model/session'
require 'logalator/progressbar'

DataMapper::Logger.new(STDOUT, :info)
DataMapper.setup(:default, "postgres://#{ARGV[0]}:#{ARGV[1]}@localhost/#{ARGV[2]}")
DataMapper.auto_upgrade!

@pp = {}
def add_pair(from,to,date)
    @pp[from] = {} unless @pp.member? from
    if @pp[from].member? to
        @pp[from][to] += 1
    else
        @pp[from][to] = 1
    end
end

def page k
    return "start" if k.eql? START 
    return "end" if k.eql? LEAF 
    Page.first(:id => k).name
end

def save_pairs
    File.open("pairs_all.txt","w+") do |f|
        @pp.keys.each do |k| 
            @pp[k].keys.each do |k2| 
                f.puts "#{page(k)}->#{page(k2)} #{@pp[k][k2]}" 
            end
        end
    end
end

si_co = SessionItem.count
puts "Session items #{si_co}"
DIVIDER = 10000
START=-1
LEAF=-2
@pb = Console::ProgressBar.new("SessionItems", si_co/DIVIDER)
i=0
Session.all.each do |s|
    SessionItem.all(:session_id => s.id).each do |si|
        @pb.inc if (i+=1) % DIVIDER == 0
        if(si.session_item_id)
            add_pair(si.session_item.page.id, si.page.id, si.date)#my parent and I
        else
            add_pair(START, si.page.id, si.date)#I as head
        end
        add_pair(si.page.id, LEAF, si.date) if 0 == SessionItem.count(:session_id => s.id, :session_item_id => si.id)#I as a leaf
    end
end
p @pp
save_pairs
@pb.finish
