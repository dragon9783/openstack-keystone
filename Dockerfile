FROM ubuntu
MAINTAINER Jeddy Liu <dragon9783@126.com>

RUN echo "manual" > /etc/init/keystone.override
RUN apt-get update && \
    apt-get -y install \
      keystone \
      python-keystoneclient \
      python-mysqldb \
      mysql-client \
      memcached \
      python-memcache \
      supervisor \
    && apt-get clean \
    && rm -f /var/lib/keystone/keystone.db

ADD startup.sh /
ADD keystone.conf /etc/keystone/keystone.conf
ADD supervisord.conf /etc/supervisor/conf.d/

EXPOSE 5000
EXPOSE 35357

WORKDIR /root
ENTRYPOINT ["/startup.sh"]
