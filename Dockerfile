FROM java:8-jdk

RUN dpkg -S /var/lib/apt/lists/*
WORKDIR /var/lib/apt
RUN mv lists lists.old
RUN mkdir -p lists/partial

RUN apt-get update && apt-get install -y wget git curl zip php5 php5-cli php5-mysql php5-xdebug php-pear ant

WORKDIR /opt

#Install Composer
RUN curl -sS https://getcomposer.org/installer | php
RUN chmod +x composer.phar
RUN mv composer.phar /usr/local/bin/composer 

#Install PHPUnit
RUN wget https://phar.phpunit.de/phpunit.phar
RUN chmod +x phpunit.phar
RUN mv phpunit.phar /usr/local/bin/phpunit

#Install CodeSniffer
RUN pear install PHP_CodeSniffer-2.3.4

#Install PHPLOC
RUN wget https://phar.phpunit.de/phploc.phar
RUN chmod +x phploc.phar
RUN mv phploc.phar /usr/local/bin/phploc

#Install PHP Depend
RUN wget http://static.pdepend.org/php/latest/pdepend.phar
RUN chmod +x pdepend.phar
RUN mv pdepend.phar /usr/local/bin/pdepend

#Install PHP Mess Detector
RUN wget -c http://static.phpmd.org/php/latest/phpmd.phar
RUN chmod +x phpmd.phar
RUN mv phpmd.phar /usr/local/bin/phpmd

#Install Copy/Paste Detector
RUN wget https://phar.phpunit.de/phpcpd.phar
RUN chmod +x phpcpd.phar
RUN mv phpcpd.phar /usr/local/bin/phpcpd

WORKDIR /

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

WORKDIR $JENKINS_HOME/jobs
RUN mkdir php-template
WORKDIR php-template
RUN wget https://raw.github.com/sebastianbergmann/php-jenkins-template/master/config.xml
WORKDIR $JENKINS_HOME/jobs


# Jenkins is ran with user `jenkins`, uid = 1000
# If you bind mount a volume from host/volume from a data container, 
# ensure you use same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

RUN chown -R jenkins:jenkins php-template/

# Jenkins home directoy is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ENV JENKINS_VERSION 1.609.3
ENV JENKINS_SHA f5ad5f749c759da7e1a18b96be5db974f126b71e

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER jenkins

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugin.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins-php.txt /opt/plugins-php.txt
COPY plugins.sh /usr/bin/plugins
RUN plugins /opt/plugins-php.txt
