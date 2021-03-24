FROM ruby:2.3.5

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
RUN gem install bundler:2.1.4

RUN mkdir /200donors
WORKDIR /200donors
COPY Gemfile /200donors/Gemfile
COPY Gemfile.lock /200donors/Gemfile.lock
RUN bundle install
COPY . /200donors

# Add a script to be executed every time the container starts.
COPY docker-entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

# Start the main process.
CMD ["rails", "server", "-b", "0.0.0.0"]
