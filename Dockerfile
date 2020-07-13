ARG RUBY_VERSION=2.7.1
FROM ruby:${RUBY_VERSION}

WORKDIR /resqued
COPY . .
RUN bundle install && \
  bundle binstubs resqued

CMD [ "bundle", "exec", "rake" ]
