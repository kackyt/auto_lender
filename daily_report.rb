# coding: utf-8

require 'rubygems'
require 'bitfinex'
require 'mail'
require 'dotenv'


Dotenv.load

status = {}

client = Bitfinex::RESTv1.new({
                                :api_key => ENV['BFX_API_KEY_REPORT'],
                                :api_secret => ENV['BFX_API_SECRET_REPORT']
                              })

client.balances.each do |b|
  if b['type'] == 'deposit'
    currency = b['currency'].downcase
    status[currency] = {amount: 0.0, available:0.0, lent: 0.0, offer_rate: 0.0 } if status[currency].nil?
    status[b['currency']][:amount] = b['amount'].to_f
    status[b['currency']][:available] = b['available'].to_f
  end
end


offers = client.credits

offers.each do |offer|
  currency = offer['currency'].downcase
  if offer['status'] == 'ACTIVE'
    rate = offer['rate'].to_f
    amount = offer['amount'].to_f
    status[currency] = {amount: 0.0, available:0.0, lent: 0.0, offer_rate: 0.0 } if status[currency].nil?
    status[currency][:offer_rate] = (status[currency][:offer_rate] * status[currency][:lent] + rate * amount) / (status[currency][:lent] + amount)
    status[currency][:lent] += amount
  end
end

omikuji = ['大吉', '吉', '中吉', '小吉', '末吉', '凶'].sample
mail_body = "今日の貸仮想通貨レポートを送ります。 今日の運勢は#{omikuji}です。\n"

status.each do |currency, st|
  if st[:amount] > 0
    formatted = "[#{currency.upcase}]\n保有数 : %.4f\n貸出可能 : %.4f (%#.1f%%)\n発注済 : %.4f (%#.1f%%)\n貸出済 : %.4f (%#.1f%%)\n年利 %#.2f%%\n" %
      [st[:amount],
      st[:available],
      st[:available] * 100 / st[:amount],
      st[:amount] - st[:available] - st[:lent],
      (st[:amount] - st[:available] - st[:lent]) * 100 / st[:amount],
      st[:lent],
      st[:lent] * 100 / st[:amount],
      st[:offer_rate]]
    mail_body << formatted
    mail_body << "-----------------------\n"
  end
end

mail = Mail.new

options = {
  address: ENV['SMTP_DOMAIN'],
  port: 465,
  domain: ENV['SMTP_DOMAIN'],
  user_name: ENV['SMTP_USER'],
  password: ENV['SMTP_PASSWORD'],
  authentication: :login,
  enable_starttls_auto: true,
  tls: true
}

mail.charset = 'utf-8'
mail.from ENV['SMTP_MAILFROM']
mail.to ENV['SMTP_MAILTO']
mail.subject 'daily lending report'
mail.body mail_body
mail.delivery_method(:smtp, options)
mail.deliver


