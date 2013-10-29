FROM ubuntu
MAINTAINER Eric Mill "eric@konklone.com"

# turn on universe packages, update to latest
RUN echo "deb http://archive.ubuntu.com/ubuntu raring main universe" > /etc/apt/sources.list
RUN apt-get update

# basics
RUN apt-get install -y nginx openssh-server git-core openssh-client curl nano build-essential openssl libreadline6 libreadline6-dev curl zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config

# Install rbenv, help from https://gist.github.com/deepak/5925003
RUN git clone https://github.com/sstephenson/rbenv.git /usr/local/rbenv
RUN echo '# rbenv setup' > /etc/profile.d/rbenv.sh
RUN echo 'export RBENV_ROOT=/usr/local/rbenv' >> /etc/profile.d/rbenv.sh
RUN echo 'export PATH="$RBENV_ROOT/bin:$PATH"' >> /etc/profile.d/rbenv.sh
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
RUN chmod +x /etc/profile.d/rbenv.sh
RUN mkdir /usr/local/rbenv/plugins
RUN git clone https://github.com/sstephenson/ruby-build.git /usr/local/rbenv/plugins/ruby-build
ENV RBENV_ROOT /usr/local/rbenv

RUN /bin/bash -l -c "rbenv install 2.0.0-p247"
RUN /bin/bash -l -c "rbenv global 2.0.0-p247"
RUN /bin/bash -l -c "gem install bundler clockwork --no-ri --no-rdoc"
RUN /bin/bash -l -c "rbenv rehash"

# check out and install konklone/fisa
RUN mkdir /apps
RUN git clone https://github.com/konklone/fisa /apps/fisa # oka

# copy over whole repository (breaks caching)
# ADD ./ /apps/fisa

# with quotes the following doesn't work! I don't understand. I don't understand.
RUN cd /apps/fisa && bash -l -c bundle install

# copy over personal configuration as last step (breaks caching)
ADD config.yml /apps/fisa/config.yml

# run a test
# RUN cd /apps/fisa && bash -l -c "bundle exec ruby fisa.rb test"
# RUN cd /apps/fisa && bash -l -c "bundle exec clockwork cron.rb"

# set crontab to run every 5 minutes
# RUN echo "*/1 * * * * cd /apps/fisa && bash -l -c bundle exec ruby /apps/fisa/fisa.rb test" | crontab
# > /apps/fisa/fisa.log 2>&1" | crontab