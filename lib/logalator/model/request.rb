class User
    include DataMapper::Resource

    has n, :requests
    has n, :session_items

    property :id, Serial
    property :ip, String
    property :agent, String, :length => 4000
    property :robot, Boolean
end

class Header
    include DataMapper::Resource

    has n, :requests

    property :id, Serial
    property :method, String, :index => true
    property :path, String, :index => true, :length => 4000 
    property :protocol, String
    property :status, String, :index => true
    property :bytes, String 
end

class Request
    include DataMapper::Resource

    belongs_to :header
    belongs_to :user

    property :id, Serial
    property :referrer, String, :length => 4000
    property :date, DateTime, :index => true
    property :nr, Integer
end
