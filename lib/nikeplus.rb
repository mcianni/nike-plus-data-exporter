#!/usr/bin/ruby

require 'rubygems'
require 'net/https'
require 'json'
require 'csv'

module Enumerable
  def flatten_with_path(parent_prefix = nil)
    res = {}

    self.each_with_index do |elem, i|
      if elem.is_a?(Array)
        k, v = elem
      else
        k, v = i, elem
      end
      key = parent_prefix ? "#{parent_prefix}.#{k}" : k # assign key name for result hash
      if v.is_a? Enumerable
        res.merge!(v.flatten_with_path(key)) # recursive call to flatten child elements
      else
        res[key] = v
      end
    end

    res
  end
end

module NikePlus
  class InvalidLoginError < StandardError; end
  class WebserviceError   < StandardError; end

  class Exporter
    attr_accessor :user, :data

    def initialize(email, password)
      cookies = login(email, password)
      @data = get_data(cookies) if cookies
    end

    def csv
      return nil unless @data
      # Data returned is inconsistent; order varies, fields may be missing row to row
      # so lets grab all the keys now, this will be the standard column order for output
      # Flatten the nested activity hash, giving it compound keys
      flattened_activities = @data['activities'].map{ |activity| activity.flatten_with_path }
      keys = flattened_activities.map(&:keys).flatten.uniq

      out = CSV.generate( :headers => keys, :write_headers => true ) do |csv|
        flattened_activities.each do |activity|
          csv << keys.map{ |key| activity[key] }
        end
      end
      out
    end

    private
    def login(email, password)
      login_path = "/nsl/services/user/login?app=b31990e7-8583-4251-808f-9dc67b40f5d2&format=json&contentType=plaintext"
      post_data = "email=#{email}&password=#{password}"
      headers = {"Content-Type" => "application/x-www-form-urlencoded"}

      url = URI("https://secure-nikeplus.nike.com")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      resp, data = http.post(login_path, post_data, headers)
      begin
        json = JSON.parse(resp.body)
      rescue JSON::ParserError => e
        raise NikePlus::WebserviceError.new("There was an error connecting to the NikePlus website. Try again later.")
      end

      unless json['serviceResponse']['header']['success'] == 'true'
        raise NikePlus::InvalidLoginError.new(JSON.parse(resp.body)['serviceResponse']['header']['errorCodes']
                                         .collect{|e| e['message']}.join("\n\t"))
      else
        @user = json['serviceResponse']['body']['User']['screenName']
      end

      all_cookies = resp.get_fields('set-cookie')
      cookies = all_cookies.collect{|c| c.split('; ')[0]}.join('; ') #make sure we set multiple cookies
      cookies
    end

    def get_data(cookies)
      data_path = "http://nikeplus.nike.com/plus/activity/running/#{@user}/lifetime/activities?indexStart=0&indexEnd=9999"
      url = URI(data_path)
      http = Net::HTTP.new(url.host, url.port)

      begin
        resp, data = http.get(data_path, {'Cookie' => cookies})
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
         Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        raise NikePlus::WebserviceError.new("There was an error connecting to the NikePlus website. Try again later.")
      else
        return JSON.parse(resp.body)
      end
    end

    def write_to_file(data)
      CSV.open("out.csv", "w") do |csv|
        data['activities'].each do |activity|
          csv << activity.flatten_with_path.values
        end
      end
    end

  end
end
