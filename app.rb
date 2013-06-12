require 'sinatra'
require 'haml'
require './lib/nikeplus.rb'

get '/' do
  haml :index
end

post '/' do
  exporter = NikePlus::Exporter.new(params[:user], params[:email], params[:password])
  @data = exporter.csv

  if @data
    content_type "text/csv"
    @data
  else
    @error_message = "Sorry, an error occured. Check your username/email/password."
    haml :index
  end
end
