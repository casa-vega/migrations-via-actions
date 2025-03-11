FROM alpine:3.11.2

LABEL version=1.10.1
LABEL description="BitBucket Server Exporter Utility for GitHub"
LABEL maintainer="GitHub Services <services@github.com>"

WORKDIR /opt/bbs-exporter

COPY Gemfile Gemfile.lock bbs_exporter.gemspec ./
COPY lib/bbs_exporter/version.rb lib/bbs_exporter/

RUN \
  DEPS=" \
    git \
    ruby \
    ruby-bigdecimal \
    ruby-etc \
    ruby-json \
    sqlite-dev \
  " && \
  BUILD_DEPS=" \
    cmake \
    g++ \
    gcc \
    make \
    ncurses-dev \
    openssl-dev \
    ruby-dev \
    yaml-dev" && \
  \
  apk add --no-cache $DEPS $BUILD_DEPS && \
  \
  bundler_version=$(sed -n '/^BUNDLED WITH$/{n;s/ *//g;p}' Gemfile.lock) && \
  gem install --no-document --version $bundler_version bundler && \
  \
  cpu_count=$(grep processor /proc/cpuinfo | wc -l) && \
  bundle config --global silence_root_warning 1 && \
  bundle install --jobs=$cpu_count

CMD /bin/sh

COPY . .

RUN bundle exec rake install
