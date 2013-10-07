FROM ubuntu
MAINTAINER Eric Mill "eric@konklone.com"

# turn on universe packages, update to latest
RUN echo "deb http://archive.ubuntu.com/ubuntu raring main universe" > /etc/apt/sources.list
RUN apt-get update

# basics
RUN apt-get install -y nginx openssh-server git-core openssh-client curl
RUN apt-get install -y nano
RUN apt-get install -y build-essential
RUN apt-get install -y openssl libreadline6 libreadline6-dev curl zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config

# install Ruby
RUN \curl -L https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.0"
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

# check out and install konklone/fisa
RUN mkdir /apps && cd /apps && git clone https://github.com/konklone/fisa && ls
# with quotes the following doesn't work! I don't understand. I don't understand.
RUN cd /apps/fisa && bash -l -c bundle install
RUN /bin/bash -l -c "gem install clockwork"


# copy over personal configuration as last step (breaks caching)
ADD config.yml /apps/fisa/config.yml

# run a test
# RUN cd /apps/fisa && bash -l -c "bundle exec ruby fisa.rb test"
# RUN cd /apps/fisa && bash -l -c "bundle exec clockwork cron.rb"

# set crontab to run every 5 minutes
# RUN echo "*/1 * * * * cd /apps/fisa && bash -l -c bundle exec ruby /apps/fisa/fisa.rb test" | crontab
# > /apps/fisa/fisa.log 2>&1" | crontab