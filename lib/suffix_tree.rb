# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
require 'pp'

    class SuffixTreeBuilder
      attr_reader :sf 
      
      def initialize
        @sf = SuffixTree.new
      end
      
      def add_tree tree, path=[]
        tree.each do |k,v| 
          path << k.request.page.name.to_sym; 
          if v.empty?
            self << path if path.size > 1
          else
            add_tree v, path
          end
        end
      end
      
      def <<(session_pages)
        (session_pages.size-1).times do
          @sf << session_pages
          session_pages.shift
        end
        self        
      end
      
      def to_s
        "suffix tree build:\n#{@sf.to_s}"
      end

      def to_s_sort file=STDOUT
        @sf.to_s_sort file
      end
    end
    
    class SuffixTree
      
      def initialize
        @sf = {}
      end
      
      def <<(pages)        
        current = @sf        
        pages.each do |page|  
          current[page] ||= {}          
          current = current[page]
          
          current[:leaf] ||= 0
          current[:leaf] += 1
        end
        self
      end
      
      def to_s
        sf_string = ''
        letter(sf_string, [], @sf)       
        sf_string
      end

      def to_s_sort file=STDOUT
          count_path = {}
          substring(count_path, [], @sf)
          count_path.sort { |a,b| if b[1].eql? a[1] then b[0].size <=> a[0].size else b[1] <=> a[1] end }.each do |k,v|
              file.puts "count: #{v} path: #{k}"
          end
      end
      
      private 
      def substring(count_path, path, hash_map)
        hash_map.each_key do |key|
          if(:leaf == key)
              count_path["#{path.map {|i| i.to_s}}"] = hash_map[:leaf] if path.size > 1 + 1 && hash_map[:leaf] > 10
          else     
            path << key
            substring(count_path, path, hash_map[key]) 
            path.pop
          end          
        end
      end

      def letter(sf_string, path, hash_map)
        hash_map.each_key do |key|
          if(:leaf == key)
            sf_string << "\tpath: #{path.map {|i| i.to_s}} with count #{hash_map[:leaf]}\r\n" if path.size > 1 + 1 && hash_map[:leaf] > 10
          else     
            path << key
            letter(sf_string, path, hash_map[key]) 
            path.pop
          end          
        end
      end
    end
=begin
   stb = SuffixTreeBuilder.new
   1.times do
    stb << %w(t a t a t t a t a t a)
    stb << %w(b a n a n a s)    
    stb << %w(k a k a j)
    end

   puts stb
=end

