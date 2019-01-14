# coding: utf-8
require 'rubygems'
require 'bitfinex'
require 'dotenv'
require 'yaml'
require 'net/http'

Dotenv.load

# disable fileの存在確認
if ENV['DISABLE_URI']
  res = Net::HTTP.get_response(URI.parse(ENV['DISABLE_URI']))
  if res.code == '200'
    # 機能を停止する
    exit
  end
end

status = YAML.load_file('config.yml')

client = Bitfinex::RESTv1.new({
                                :api_key => ENV['BFX_API_KEY'],
                                :api_secret => ENV['BFX_API_SECRET']
                              })

offers = client.offers

offers.each do |offer|
  if status[offer['currency'].downcase] &&
     offer['timestamp'].to_f + 600 < Time.now.to_f &&
                                offer['is_live']
    puts "cancel offer #{offer['id']}"
    client.cancel_offer(offer['id'])
  end
end

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
  if stat['available'] > stat['amount'] * 0.01
    amount = stat['available']

    if stat['rate'] == 0
      lends = client.lends(name, {limit_lends: 3})
      sum = lends.inject([0, 0]) do |memo, l|
        [memo[0] + l['rate'].to_f * l['amount_used'].to_f,
         memo[1] + l['amount_used'].to_f]
      end

      frr = sum[0] / sum[1]

      book = client.funding_book(name, {limit_bids: 0, limit_asks: 5})
      sum = book['asks'].inject([0, 0]) do |memo, b|
        [memo[0] + b['rate'].to_f * b['amount'].to_f,
         memo[1] + b['amount'].to_f]
      end

      bookrate = sum[0] / sum[1]
      rate = (frr + bookrate) / 2
    else
      book = client.funding_book(name, {limit_bids: 0, limit_asks: 1})
      toprate = book['asks'][0]['rate'].to_f
      rate = [stat['rate'] * 365, toprate].max
    end

    period = 2
    if stat['period']
      period = stat['period']
    end

    if stat['end']
      today = DateTime.now
      enddate = DateTime.strptime(stat['end'], '%F')
      period = (enddate - today).round
      p period
    end

    if period > 30
      period = 30
    end

    puts "offer name = #{name} amount = #{amount} rate = #{rate} period = #{period}"
    if period >= 2
      client.new_offer(name, amount, rate, period, 'lend')
    end
  end
end
