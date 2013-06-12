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
  class Exporter
    attr_accessor :user, :data

    def initialize(user, email, password)
      @user = user
      cookies = login(email, password)
      @data = get_data(user, cookies) if cookies
    end

    def csv
      return nil unless @data

      out = CSV.generate do |csv|
        @data['activities'].each do |activity|
          csv << activity.flatten_with_path.values
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

      unless JSON.parse(resp.body)['serviceResponse']['header']['success'] == 'true'
        error_message  = "Could not login. Server returned the following error(s):"
        error_message += "\t" + JSON.parse(resp.body)['serviceResponse']['header']['errorCodes'].collect{|e| e['message']}.join("\n\t")
        return nil
      end

      all_cookies = resp.get_fields('set-cookie')
      cookies = all_cookies.collect{|c| c.split('; ')[0]}.join('; ') #make sure we set multiple cookies
      cookies
    end

    def get_data(user, cookies)
      data_path = "http://nikeplus.nike.com/plus/activity/running/#{user}/lifetime/activities?indexStart=0&indexEnd=9999"
      url = URI(data_path)
      http = Net::HTTP.new(url.host, url.port)
      resp, data = http.get(data_path, {'Cookie' => cookies})
      data = JSON.parse(resp.body)
      data
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
