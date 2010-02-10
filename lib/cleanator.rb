require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'logalator/model/request'
require 'logalator/model/session'
require 'logalator/progressbar'

DataMapper.setup(:default, "postgres://#{ARGV[0]}:#{ARGV[1]}@localhost/#{ARGV[2]}")
DataMapper.auto_upgrade!
@junk = []
File.open('logalator/junk_paths.txt').each_line { |j| @junk << Regexp.new(j.strip) unless "#" == j[0] || j.strip.size == 0}

def junk?(req)
    h = req.header
    h.status !~ /^[23][0-9]{2}$/ || h.method !~ /GET|POST/ || req.user.robot ||  @junk.any? { |j| h.path =~ j}
end

def page_name(path)
    if path =~ /\/+([^\?\/]+?)\//
        servlet = $1
        return "#{servlet}" if servlet == "Content" || servlet == "queryStats" || servlet  == "zipContent"
        if servlet == "dlibra"
            return "dl:main" if path =~ /^\/+dlibra\/\?/ || path =~ /^\/+dlibra\/$/
            return "dl:#{$1}" if( path =~ /^\/+dlibra\/([^\/]+?)\?/ || path =~ /^\/+dlibra\/([^\/]+?)\// || path =~ /^\/+dlibra\/([^\?\/]+)$/)
        end
        if servlet == "publication"
            return "pub" if path =~ /^\/+publication\/\d+/  || path =~ /^\/+publication\?/
            return "pub:#{$1}" if(path =~ /^\/+publication\/([^\/]+?)\?/ || path =~ /^\/+publication\/([^\/]+?)\// || path =~ /^\/+publication\/([^\?\/]+)$/)
        end
        if servlet == "guanxi_idp"
            return "gx_idp:#{$1}" if( path =~ /^\/+guanxi_idp\/(.+?)\?/ || path =~ /^\/+guanxi_idp\/(.+?)\// || path =~ /^\/+guanxi_idp\/([^\?\/]+)$/)
        end
        if servlet == "jnlp"
            return "jnlp" if path =~ /^\/+jnlp\/(.+?)\.jar/ || path =~ /^\/jnlp\/$/
            return "jnlp:#{$1}" if(path =~ /^\/+jnlp\/(.+?)\?/ || path =~ /^\/+jnlp\/(.+?)\// || path =~ /^\/+jnlp\/([^\?\/]+)$/)
        end
    else
        path =~ /\/+(.*)$/
        file = $1
        return "rss:planned" if file =~ /^planned.*\.rss$/
        return "rss:latest" if file =~ /^latest.*\.rss$/
        return "rss:news" if file =~ /^news.*\.rss$/
        return "search_plugin" if file =~ /\.xml$/
        return "dl:main" if file == "dlibra" || file =~ /^dlibra\?$/ || file =~ /^dlibra\?/ || file =~ /^\/dlibra\?/
        return "/" if file == "" || file =~ /^\?/
        return "#{file}" if file == "dlibra.html" || file == "sitemap.xml" || file ==  "index.html" || file == "index-loading.html"
     end
     puts "page name for unknown #{path}"
     return path[0..4000] if path.size > 4000
     return path
end

def page(path)
    Page.first_or_create(:name => page_name(path))
end

DIVIDER = 10000
r_co = Request.count
puts "Requests #{r_co}"
min_id= Request.min(:id)
max_id = Request.max(:id)
@pb = Console::ProgressBar.new("Requests", r_co/DIVIDER)
i=0
(min_id..max_id).each_slice(10000) do |ids|
    SessionItem.transaction do |t|
        Request.all(:id.gte => ids.first, :id.lte => ids.last).each do |r|
            @pb.inc if i % DIVIDER == 0
            i+=1
            next if junk? r
            SessionItem.create(:request => r, :user => r.user, :header => r.header, :page => page(r.header.path), :referrer => r.referrer, :date => r.date, :nr => r.nr) 
        end #all
    end #transaction
end
@pb.finish
