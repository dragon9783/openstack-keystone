#!/bin/bash


ADMIN_TOKEN=`cat /etc/keystone/keystone.conf | grep ^admin_token | awk -F'=' '{print $2}'`
MYSQL_USER=`cat /etc/keystone/keystone.conf | grep ^connection | awk -F ['/',':','@'] '{print $4}'`
MYSQL_PASS=`cat /etc/keystone/keystone.conf | grep ^connection | awk -F ['/',':','@'] '{print $5}'`
MYSQL_HOST=`cat /etc/keystone/keystone.conf | grep ^connection | awk -F ['/',':','@'] '{print $6}'`
ADMIN_TENANT_NAME=${OS_TENANT_NAME:-admin}
ADMIN_USER_NAME=${OS_USERNAME:-admin}
ADMIN_PASSWORD=${OS_PASSWORD:-ADMIN_PASS}
ADMIN_EMAIL=${OS_ADMIN_EMAIL:-${ADMIN_USER_NAME}@example.com}
OS_SERVICE_TOKEN=$ADMIN_TOKEN
OS_SERVICE_ENDPOINT="http://${HOSTNAME}:35357/v2.0"

db_sync(){
  su -s /bin/sh -c "keystone-manage db_sync" keystone
}

init_db(){
  keystone tenant-create --name $ADMIN_TENANT_NAME --description "Admin Tenant"
  keystone user-create --name $ADMIN_USER_NAME --pass $ADMIN_PASSWORD --email $ADMIN_EMAIL
  keystone role-create --name admin
  keystone user-role-add --tenant $ADMIN_TENANT_NAME --user $ADMIN_USER_NAME --role admin
  keystone role-create --name _member_
  keystone user-role-add --tenant $ADMIN_TENANT_NAME --user $ADMIN_USER_NAME --role _member_
  keystone tenant-create --name service --description "Service Tenant"
  keystone service-create --name keystone --type identity --description "OpenStack Identity"
  KEYSTONE_HOST=$HOSTNAME
  keystone endpoint-create \
    --service-id $(keystone service-list | awk '/ identity / {print $2}') \
    --publicurl http://${KEYSTONE_HOST}:5000/v2.0 \
    --internalurl http://${KEYSTONE_HOST}:5000/v2.0 \
    --adminurl http://${KEYSTONE_HOST}:35357/v2.0 \
    --region regionOne
}

init() {

  RESULT=$(mysql -N -s -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" -e "select count(*) from information_schema.tables where table_schema='keystone' and table_name='migrate_version';")
  EXIT=$?

  if [ "$EXIT" -eq "1" ]; then
    echo "MySQL Error.  Please fix"
    exit 127;
  elif [ "$RESULT" -eq "1" ]; then
    echo "The keystone database has already been configured"
    echo "INITILIAZATION IS COMPLETE"
  else
    echo "The keystone database is missing the schema, initializing..."
    db_sync;
  fi

  /usr/bin/keystone-all &
  sleep 2;

  export OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
  if [ $(keystone user-list |grep admin |wc -l) -ne 1 ]; then
    echo "Don't find the admin user, adding the admin  tenant/role/user";
    init_db;
  fi
  unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

  pkill keystone-all
  sleep 3
}


init;

exec /usr/bin/supervisord -n
