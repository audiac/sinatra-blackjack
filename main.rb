require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'ghbftyjncdeujm'

helpers do
  def calculate_total(cards)
    values = cards.collect { |card| card[1] }

    total = 0
    values.each do |value|
      if value == 'A'
        total += 11
      else
        total += value.to_i == 0 ? 10 : value.to_i
      end
    end

    # correct total for aces when over 21
    values.select { |element| element == 'A' }.count.times do
      break if total <= 21
      total -= 10
    end

    total
  end
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  session[:player_name] = params[:player_name]
  redirect '/game'
end

get '/game' do
  # deck
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!
  # deal cards
  # dealer cards
  session[:dealer_cards] = []
  # player cards
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  erb :game
end