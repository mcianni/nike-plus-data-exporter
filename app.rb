require 'sinatra'
require 'haml'
require './lib/nikeplus.rb'

get '/' do
  haml :index
end

post '/' do
  exporter = NikePlus::Exporter.new(params[:user], params[:email], params[:password])
  @data = exporter.csv

  content_type "text/csv"
  @data
end
