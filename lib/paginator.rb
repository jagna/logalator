require 'rubygems'
require 'date'
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
    File.open("pairs_all_#{ARGV[2]}.txt","w+") do |f|
        @pp.keys.each do |k| 
            @pp[k].keys.each do |k2| 
                f.puts "#{page(k)}->#{page(k2)} #{@pp[k][k2]}" 
            end
        end
    end
end

APPLET_PAGE = Page.first(:name => "dl:applet").id
CONTENT_PAGE = Page.first(:name => "Content").id

def add_ac?(s, si)
    return false unless si.page.id.eq?(APPLET_PAGE)
end

#finds apropriate session between users
#then between robots
def add_ac(s,last_item)
    add_ac_user(s,last_item) || add_ac_robot(s,last_item)
end

CONTENT_RE = /\/Content\//
def add_ac_robot(last_s,last_item)
    robots = User.all(:id.not => last_item.user.id, :ip => last_item.user.ip, :robot => true, :agent.like => '%Java/%')
    return false unless robots.any?
    pp "Robots #{users.size}"
    u_range=(last_item..(last_item + 10.0/24/60))
    Request.all(:user => users, :date => u_range, :order => :date).each do |r|
        next unless r.header.path =~ CONTENT_RE

        add_pair(last_item.page.id,CONTENT_PAGE,r.date)
        add_pair(CONTENT_PAGE,LEAF,r.date)
        break
    end
end

def add_ac_user(last_s,last_item)
    users = User.all(:id.not => last_item.user.id, :ip => last_item.user.ip, :robot => false, :agent.like => '%Java/%')
    return false unless users.any?
    pp "Users #{users.size}"
    #last time date + 10 minutes range
    time_range=(last_item.date..(last_item.date + 10.0/24/60))
    Session.all(:id.not => last_s.id, :user => users, :start_date.lte => last_item.date, :end_date.gte => last_item.date, :order => :start_date).each do |s|
        item = SessionItem.first(:session_id => s.id, :session_item_id => nil, :date => time_range, :page_id => CONTENT_PAGE, :order => :date)
        next unless item.nil?
        add_pair(last_item.page.id,item.page.id,item.date)
        @ac_items << item.id
        break
    end
end

def create_pairs(s)
    SessionItem.all(:session_id => s.id, :order => :date).each do |si|
        @pb.inc if (i+=1) % DIVIDER == 0
        if(si.session_item_id)
            add_pair(si.session_item.page.id, si.page.id, si.date)#my parent and I
        else
            add_pair(START, si.page.id, si.date) unless @ac_items.member? si.id #I as head if not already merged as a content
        end
        if 0 == SessionItem.count(:session_id => s.id, :session_item_id => si.id)#I as a leaf
            if add_ac?(s, si)
                add_ac(s,si)
            else
                add_pair(si.page.id, LEAF, si.date)
            end
        end
    end
end

if ARGV[3] & ARGV[4]
    u_from=DateTime.new(ARGV[4],12,ARGV[3].to_i)
    u_to=DateTime.new(ARGV[4],12,ARGV[3].to_i,23,59,59) 
    u_range=(u_from..u_to)
    si_co = SessionItem.count(:date => u_range )
else
    si_co = SessionItem.count
end
puts "Session items #{si_co}"
DIVIDER = 10000
START=-1
LEAF=-2
@pb = Console::ProgressBar.new("SessionItems", si_co/DIVIDER)
i=0
#applet content users
@ac_items= []
if ARGV[3]
    (Session.all(:start_date => u_range) & Session.all(:end_date => u_range)).each { |s| create_pairs(s) }
else
    Session.all(:order => :start_date).each { |s| create_pairs(s) }
end
p @pp
save_pairs
@pb.finish
p @ac_items
