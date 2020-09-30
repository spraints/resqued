ARG RUBY_VERSION=2.7.1
FROM ruby:${RUBY_VERSION}

WORKDIR /resqued
COPY Gemfile Gemfile
COPY resqued.gemspec resqued.gemspec
COPY lib/resqued/version.rb lib/resqued/version.rb
COPY exe exe
RUN bundle install && \
  bundle binstubs resqued
COPY . .

CMD [ "bundle", "exec", "rake" ]
