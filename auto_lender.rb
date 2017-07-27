require 'rubygems'
require 'bitfinex'
require 'dotenv'
require 'yaml'

Dotenv.load

status = YAML.load_file('config.yml')

Bitfinex::Client.configure do |conf|
  conf.secret = ENV['BFX_API_SECRET']
  conf.api_key = ENV['BFX_API_KEY']
end

client = Bitfinex::Client.new

client.balances.each do |b|
  if b['type'] == 'deposit'
    if status[b['currency']]
      status[b['currency']]['amount'] = b['amount'].to_f
      status[b['currency']]['available'] = b['available'].to_f
    end
  end
end

p status

status.each do |name, stat|
  if stat['available'] > stat['amount'] * 0.1
    book = client.funding_book(name, {limit_bids: 0, limit_asks: 1})
    toprate = book['asks'][0]['rate'].to_f
    amount = stat['available']
    rate = [stat['rate'] * 365, toprate].max
    period = 2
    if stat['period']
      period = stat['period']
    end

    if stat['end']
      today = Datetime.now
      enddate = Datetime.strptime(stat['end'], '%F')
      period = enddate - today
    end

    if period > 30
      period = 30
    end

    puts "offer name = #{name} amount = #{amount} rate = #{rate} period = #{period}"
    client.new_offer(name, amount, rate, period, 'lend')
  end
end
