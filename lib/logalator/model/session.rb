class Page
    include DataMapper::Resource

    has n, :session_items

    property :id, Serial
    property :name, String, :length => 4000
end

class Session
    include DataMapper::Resource

    has n, :session_items
    belongs_to :user
    belongs_to :start, 'SessionItem'
    belongs_to :end, 'SessionItem'

    property :id, Serial
    property :start_date, DateTime
    property :end_date, DateTime
end

class SessionItem 
    include DataMapper::Resource

    belongs_to :header
    belongs_to :user
    belongs_to :request
    belongs_to :page
    belongs_to :session_item, :required => false
    belongs_to :session, :required => false

    property :id, Serial
    property :referrer, String, :length => 4000
    property :date, DateTime, :index => true
    property :nr, Integer

    def same_session?(other) 
        return true if other.nil?
        (other.date.to_time.to_i - date.to_time.to_i).abs <= 30*60
    end

  end
