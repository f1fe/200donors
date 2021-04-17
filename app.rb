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
    from 'Joe Canney, New Covenant School <school@newcovschool.net>'
    subject 'Grow NCS!'
      text_part do
        body "Thank you so much for participating in Grow NCS! New Covenant School partners with Christian parents and the local church to help fulfill the call to make Christ-like disciples of God’s children (Colossians 1:28). We're constantly amazed at the generosity of each of you who are committed to this vision.
  
        We hope you'll share this with your friends and family and help us finish this fundraiser before the end of the school year.
    
        Thanks again, and please let me know if you have any questions our school.
  
        Blessings,
  
        Joe Canney
        Head of School
  
        PS - You can keep up with the progress at http://grow-ncs.org/goal
  
  
        "
      end
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "<p>Thank you so much for participating in Grow NCS! New Covenant School partners with Christian parents and the local church to help fulfill the call to make Christ-like disciples of God’s children (Colossians 1:28). We're constantly amazed at the generosity of each of you who are committed to this vision.</p>
  
        <p>We hope you'll share this with your friends and family and help us finish this fundraiser before the end of the school year.</p>

        <p>Thanks again, and please let me know if you have any questions our school.</p>
  
        <p>Blessings,</p>
  
        <p>Joe Canney<br/>
        Head of School</p>
  
        <p>PS - You can keep up with the progress at http://grow-ncs.org/goal</p><br/><br/><br/>"
        
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
          name: 'Grow NCS!',
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
