require 'sinatra'
require 'haml'
require './lib/nikeplus.rb'

get '/' do
  haml :index
end

post '/' do
  begin
    exporter = NikePlus::Exporter.new(params[:email], params[:password])
    @data = exporter.csv
  rescue NikePlus::InvalidLoginError, NikePlus::WebserviceError => e
    @error_message = e
    haml :index
  else
    content_type "text/csv"
    @data
  end

end
