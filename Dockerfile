ARG RUBY_VERSION=2.7.1
FROM ruby:${RUBY_VERSION}

ARG CI_GEMFILE=Gemfile

WORKDIR /resqued
COPY Gemfile Gemfile
COPY gemfiles gemfiles
RUN test "$CI_GEMFILE" = "Gemfile" || cat "$CI_GEMFILE" | sed -e 's/^gemspec.*/gemspec/' > Gemfile && cat Gemfile
COPY resqued.gemspec resqued.gemspec
COPY lib/resqued/version.rb lib/resqued/version.rb
COPY exe exe
RUN bundle install && \
  bundle binstubs resqued
COPY . .

CMD [ "bundle", "exec", "rake" ]
