require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'ghbftyjncdeujm'

BLACKJACK = 21
DEALER_HIT_MIN = 17
INITIAL_POT_AMOUNT = 500


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
      break if total <= BLACKJACK
      total -= 10
    end

    total
  end

  def card_image(card)
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_pot] += session[:player_bet]
    @winner = "<strong>#{session[:player_name]} wins! #{msg}</strong>"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_pot] -= session[:player_bet]
    @loser = "<strong>#{session[:player_name]} loses. #{msg}</strong>"
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @winner = "<strong>It's a tie! #{msg}</strong>"
  end

  def reveal_dealer_card
    session[:turn] = "dealer"
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_pot] = INITIAL_POT_AMOUNT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i <= 0
    @error = "Please make a bet."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "Bet amount cannot be greater than $#{session[:player_pot]}."
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]

  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK
    reveal_dealer_card
    loser!("Dealer hit blackjack.")
  elsif player_total == BLACKJACK
    winner!("#{session[:player_name]} hit blackjack!")
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
    winner!("#{session[:player_name]} hit blackjack!")
  elsif player_total > BLACKJACK
    loser!("#{session[:player_name]} busted with #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK
    loser!("Dealer hit blackjack.")
  elsif dealer_total > BLACKJACK
    @success = "Dealer busted!"
    winner!("Dealer busted with #{dealer_total}.")
  elsif dealer_total >= DEALER_HIT_MIN
    redirect '/game/compare'
  else
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} has #{player_total}. Dealer has #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} has #{player_total}! Dealer has #{dealer_total}.")
  else
    tie!("#{session[:player_name]} and the Dealer push with #{player_total}.")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end