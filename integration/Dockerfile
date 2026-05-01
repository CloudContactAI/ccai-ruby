FROM ruby:3.2-slim

RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

WORKDIR /sdk
COPY Gemfile Gemfile.lock ccai.gemspec ./
COPY lib/ ./lib/
RUN bundle install

COPY integration/Gemfile ./integration/
WORKDIR /sdk/integration
RUN bundle install

COPY integration/ ./
CMD ["bundle", "exec", "ruby", "test.rb"]
