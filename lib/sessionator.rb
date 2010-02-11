require 'rubygems'
require 'time'
require 'dm-core'
require 'dm-aggregates'
require 'logalator/model/request'
require 'logalator/model/session'
require 'logalator/progressbar'

DataMapper::Logger.new(STDOUT, :info)
DataMapper.setup(:default, "postgres://#{ARGV[0]}:#{ARGV[1]}@localhost/#{ARGV[2]}")
DataMapper.auto_upgrade!

SITE = "http://www.wbc.poznan.pl"
NO_REF = "-"
EMPTY = "" 
CONTENT_PAGE = Page.first(:name => "Content").id 
APPLET_PAGE = Page.first(:name => "dl:applet").id 
CONTENT = [CONTENT_PAGE, APPLET_PAGE] 

def first_or_outside?(si,cp,pub_id)
    return false if CONTENT.member?(si.page_id) && si.referrer.eql?(NO_REF) && cp.keys.member?(pub_id)
    idx = si.referrer.index(SITE)
    idx.nil? || 0 != idx
end

def pub_id si
    return false if !CONTENT.member? si.page_id
    return $1.to_i if CONTENT_PAGE == si.page_id && /^\/Content\/(\d+)\// =~ si.header.path 
    return $1.to_i if APPLET_PAGE == si.page_id && /^\/dlibra\/applet\?.*content_url=\/Content\/(\d+)\// =~ si.header.path
    false 
end

def create_session(session)
    s = Session.new
    s.user_id = session.first.user_id
    s.start = session.first
    s.end = session.last
    s.start_date = session.first.date
    s.end_date = session.last.date
    s.save
    s.id
end

@site_no_parents = 0
def save(session)
    s_id = create_session(session)
    p = {}#parents
    cp = {}#content parents
    session.each do |si|
        pub_id = pub_id si
        if !first_or_outside?(si,cp,pub_id) && !p.empty?
            site_path = si.referrer.gsub(SITE,EMPTY)
            si.session_item_id = p[site_path] || cp[pub_id] #saving at the end of loop
            @site_no_parents+=1 if si.session_item_id.nil? #it happens if session time out
        end 
        p[si.header.path]=si.id 
        cp[pub_id]=si.id if pub_id
        si.session_id = s_id
        si.save
    end
end

si_co = SessionItem.count
puts "Session items #{si_co}"
DIVIDER = 10000
@pb = Console::ProgressBar.new("SessionItems", si_co/DIVIDER)
i=0
User.all(:robot => false).each do |u|
    usi_co = SessionItem.all(:user_id => u.id).count
    next if 0 == usi_co
    session = []
    #u.session_items.all.each do |si|
    SessionItem.all(:user_id => u.id, :order => [:date, :nr]).each do |si|
        @pb.inc if (i+=1) % DIVIDER == 0
        
        if(si.same_session?(session.last))
            session << si
            next
        end

        save(session)#saving previous session
        session = []#creating new one
        session << si
    end
    save(session)#saving last session
end
puts "Not found referrers from site: #{@site_no_parents}"
@pb.finish
