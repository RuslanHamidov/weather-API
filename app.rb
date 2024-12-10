require 'sinatra'
require 'sinatra/json'
require 'faraday'
require 'faraday/retry'
require 'dotenv/load'
require 'redis'

api_key = ENV['API_KEY']
redis_url = ENV['REDIS_URL']
redis = Redis.new(url: redis_url)

conn = Faraday.new(url: 'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline') do |faraday|
  faraday.response :logger
  faraday.request :retry, max: 3, interval: 0.5
  faraday.adapter Faraday.default_adapter
end

get '/weather/:city' do
  city = params['city']
  value = redis.get(city)

  if value
    puts "Cache hit for #{city}"
    json JSON.parse(value)
  else
    puts "Cache miss for #{city}"
  end

  response = conn.get("#{city}/today") do |req|
    req.params['elements'] = 'datetime,datetimeEpoch,temp,tempmax,tempmin,precip,windspeed,windgust,feelslike'
    req.params['include'] = 'fcst,obs,histfcst,stats'
    req.params['key'] = api_key
    req.params['contentType'] = 'json'
    end

  if response.status == 200
    redis.set(city, response.body, ex: 3600)
    json JSON.parse(response.body)
  else
    status response.status
    json error: "Error fetching weather data", details: response.body
  end
end
