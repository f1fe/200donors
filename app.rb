require 'sinatra'
if Sinatra::Base.development?
  require 'pry'
  require 'dotenv'
  Dotenv.load
end
require 'stripe'
require 'mail'
require_relative 'database'

Database.initialize

set :publishable_key, ENV['PUBLISHABLE_KEY']
set :secret_key, ENV['SECRET_KEY']
set :success_url, ENV['SUCCESS_URL']
set :cancel_url, ENV['CANCEL_URL']
enable :sessions

Stripe.api_key = settings.secret_key

Mail.defaults do
  delivery_method :smtp, { :address   => "smtp.sendgrid.net",
                           :port      => 587,
                           :domain    => ENV['SENDGRID_DOMAIN'],
                           :user_name => ENV['SENDGRID_USER'],
                           :password  => ENV['SENDGRID_PW'],
                           :authentication => 'plain',
                           :enable_starttls_auto => true }
end

# Marking offline donations paid from console. Probably not the best wat to do this, whatevs
def markpaid(amount)
    pay = Donation.last(:amount => amount)
    pay.paid = true
    pay.save
end

def send_thanks
  mail = Mail.deliver do

    # fix this... need to get the customer.email
    to customer.email
    from 'Ryan McCrary <ryan@goattrips.org>'
    subject 'Grow NCS!'
      text_part do
        body "Thank you so much for participating in GOAT Christmas! We're constantly amazed at the generosity of each of you who make GOAT possible for the kids that we serve.
  
        We hope you'll share this with your friends and family and help us finish this fundraiser out before the end of the year.
  
        As a way of saying thanks, we'd love for you to pick out something you like in the GOAT shop (http://goattrips.org/shop) and use the coupon 2017christmas so we can send it free. Don't feel bad about it - we actually pay our GOAT students to help ship orders, so you're helping them out by ordering free stuff!
  
        You'll also recieve a tax receipt first thing next year!
  
        Thanks again so much, and please let us know if you have any questions about GOAT or GOAT Christmas!
  
        Merry Christmas!
  
        Ryan & The GOAT Team
  
        PS - You can keep up with the progress at http://www.goatchristmas.com/goal
  
  
        "
      end
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "<p>Thank you so much for participating in GOAT Christmas! We're constantly amazed at the generosity of each of you who make GOAT possible for the kids that we serve.</p>
  
        <p>We hope you'll share this with your friends and family and help us finish this fundraiser out before the end of the year.</p>
  
        <p>As a way of saying thanks, we'd love for you to pick out something you like in the GOAT shop (http://goattrips.org/shop) and use the coupon <b>2017christmas</b> so we can send it free. Don't feel bad about it - we actually pay our GOAT students to help ship orders, so you're helping them out by ordering free stuff!</p>
  
        <p>We'll also be sending you a small thank you in the following weeks, so keep an eye on your mailbox. You'll also recieve a tax receipt first thing next year!</p>
  
        <p>Thanks again so much, and please let us know if you have any questions about GOAT or GOAT Christmas!</p>
  
        <p>Merry Christmas!</p>
  
        <p>Ryan & The GOAT Team</p>
  
        <p>PS - You can keep up with the progress at http://www.goatchristmas.com/goal</p><br /><br /><br />"
      end
    end  
end


get '/' do
  @donations = Donation.all
  @done = Donation.all(:paid => 'true')
  @total = 0
  @done.each do |done|
    @total += done.amount
  end
  erb :index
end

get '/goal' do
  @done = Donation.all(:paid => 'true')
  @total = 0
  @done.each do |done|
    @total += done.amount
  end
  erb :goal
end

post '/checkout' do
  @donation = Donation.get(params[:donation_id])
  donation = @donation

  stripe_session = Stripe::Checkout::Session.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'Grow NCS',
        },
        unit_amount: @donation.amount*100,
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: settings.success_url, # /thanks
    cancel_url: settings.cancel_url  # /
  })

  session[:donation_id] = @donation.id

  { id: stripe_session.id }.to_json
end

get '/thanks' do
  @error = session[:error]
  if @error
    halt erb(:thanks)
  end

  @donation = Donation.get(session[:donation_id])
  @donation.update(paid: 'true')

  paid_donations = Donation.all(paid: 'true')
  @total = 0
  paid_donations.each do |done|
    @total += done.amount
  end

  erb :thanks
end
