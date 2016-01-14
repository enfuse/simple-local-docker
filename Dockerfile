FROM ubuntu:14.04.3
MAINTAINER Juanjo López <juanjo.lopez@gmail.com>

#
# Step 1: Installation
#

# Set frontend. We'll clean this later on!
ENV DEBIAN_FRONTEND noninteractive

# Expose web root as volume
VOLUME ["/var/www"]

# Add additional repostories needed later
RUN echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu trusty main" >> /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E1DF1F24

# Update repositories cache and distribution
RUN apt-get -qq update && apt-get -qqy upgrade

# Install some basic tools needed for deployment
RUN apt-get -yqq install apt-utils sudo build-essential debconf-utils locales curl wget unzip patch dkms supervisor

# Add the docker user
ENV HOME /home/docker
RUN useradd docker && passwd -d docker && adduser docker sudo
RUN mkdir -p $HOME && chown -R docker:docker $HOME

# Install SSH client
RUN apt-get -yqq install openssh-client

# Install ssmtp MTA
RUN apt-get -yqq install ssmtp

# Install Apache web server
RUN apt-get -yqq install apache2-mpm-prefork

# Install MySQL server and save initial configuration
RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
RUN apt-get -yqq install mysql-server
RUN service mysql start && service mysql stop & tar cpPzf /mysql.tar.gz /var/lib/mysql

# Install PHP5 with Xdebug, APC and other modules
RUN apt-get -yqq install libapache2-mod-php5 php5-mcrypt php5-dev php5-mysql php5-curl php5-gd php5-intl php5-xdebug php-apc

# Install PEAR package manager
RUN apt-get -yqq install php-pear && pear channel-update pear.php.net && pear upgrade-all

# Install PECL package manager
RUN apt-get -yqq install libpcre3-dev

# Install PECL uploadprogress extension
RUN pecl install uploadprogress

# Update APC to latest version
RUN printf "\n" | pecl update apc

# Install memcached service
RUN apt-get -yqq install memcached php5-memcached

# Install GIT (latest version)
RUN apt-get -yqq install git

# Install composer (latest version)
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Install drush (latest stable)
RUN composer global require drush/drush
# RUN composer global require drush/drush:6.*
# RUN wget http://files.drush.org/drush.phar
# RUN php drush.phar core-status
# RUN chmod +x drush.phar
# RUN mv drush.phar /usr/local/bin/drush

# USER docker

# RUN drush init

USER root

# Install PhpMyAdmin (latest version)
RUN wget -q -O phpmyadmin.zip http://files.phpmyadmin.net/phpMyAdmin/4.5.3.1/phpMyAdmin-4.5.3.1-all-languages.zip && unzip -qq phpmyadmin.zip
RUN rm phpmyadmin.zip && mv phpMyAdmin*.* /opt/phpmyadmin

# Install zsh / OH-MY-ZSH
RUN apt-get -yqq install zsh && git clone git://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh

# Install PROST drupal deployment script, see https://www.drupal.org/sandbox/axroth/1668300
RUN git clone --branch master http://git.drupal.org/sandbox/axroth/1668300.git /tmp/prost
RUN chmod +x /tmp/prost/install.sh

# Install some useful cli tools
RUN apt-get -yqq install mc htop vim pv

# Cleanup some things
RUN apt-get -yqq autoremove; apt-get -yqq autoclean; apt-get clean


RUN wget -q -O mailhog https://github.com/mailhog/MailHog/releases/download/v0.1.7/MailHog_linux_386 && mv mailhog /usr/sbin/mailhog && chmod a+x /usr/sbin/mailhog
RUN wget -q -O mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v0.1.9/mhsendmail_linux_386 && mv mhsendmail /usr/sbin/mhsendmail && chmod a+x /usr/sbin/mhsendmail
#RUN sed -i 's/;sendmail_path =/sendmail_path=\/usr\/sbin\/mhsendmail/g' /etc/php5/apache2/php.ini

# Install pantheon cli tools
# curl https://github.com/pantheon-systems/cli/releases/download/0.10.1/terminus.phar -L -o /usr/local/bin/terminus && chmod +x /usr/local/bin/terminus
RUN composer require pantheon-systems/cli


# Expose some ports to the host system (web server, MySQL, Xdebug)
EXPOSE 80 443 3306 9000 1025 8025

#
# Step 2: Configuration
#

# Localization
RUN dpkg-reconfigure locales && locale-gen es_ES.UTF-8 && /usr/sbin/update-locale LANG=es_ES.UTF-8
ENV LC_ALL es_ES.UTF-8

# Set timezone
RUN echo "Europe/Madrid" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

# Add apache web server configuration file
ADD config/httpd.conf /etc/apache2/httpd.conf

# Add apache vhosts
ADD config/vhosts/*.conf /etc/apache2/sites-available/

# Add apache web server configuration file
# RUN ln -s -f /etc/apache2/sites-available/* /etc/apache2/sites-enabled/

# Disable default ssl site
RUN a2dissite default-ssl

# Configure needed apache modules and disable default site
RUN a2enmod rewrite headers deflate expires ssl && a2dismod cgi autoindex status #&& a2dissite default

# Add additional php configuration file
ADD config/php.ini /etc/php5/conf.d/php.ini

# Add additional mysql configuration file
ADD config/mysql.cnf /etc/mysql/conf.d/mysql.cnf

# Add memcached configuration file
ADD config/memcached.conf /etc/memcached.conf

# Add ssmtp configuration file
ADD config/ssmtp.conf /etc/ssmtp/ssmtp.conf

# Add phpmyadmin configuration file
ADD config/config.inc.php /opt/phpmyadmin/config.inc.php

# Add git global configuration files
ADD config/.gitconfig $HOME/.gitconfig
ADD config/.gitignore $HOME/.gitignore

# Add drush global configuration file
ADD config/drushrc.php $HOME/.drush/drushrc.php


# Add apc status script
# RUN mkdir /opt/apc && gunzip -c /usr/share/doc/php-apc/apc.php.gz > /opt/apc/apc.php

# Add zsh configuration
ADD config/.zshrc $HOME/.zshrc

# Configure PROST drupal deployment script
RUN chown docker:docker $HOME/.zshrc
USER docker
ENV SHELL /bin/zsh
RUN export PATH="$HOME/.composer/vendor/bin:$PATH" && cd /tmp/prost && ./install.sh -noupdate $HOME/.prost
USER root
RUN rm -rf /tmp/prost

# ADD ssh keys needed for connections to external servers
ADD .ssh $HOME/.ssh
RUN echo "    IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config

# Add startup script
ADD startup.sh $HOME/startup.sh

# Supervisor configuration
ADD config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Entry point for the container
RUN chown -R docker:docker $HOME && chmod +x $HOME/startup.sh
USER docker
ENV SHELL /bin/zsh
WORKDIR /var/www
CMD ["/bin/bash", "-c", "$HOME/startup.sh"]
