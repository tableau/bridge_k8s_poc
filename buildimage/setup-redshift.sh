#!/usr/bin/env  bash

set -e

yum install -y unixODBC
yum --nogpgcheck localinstall -y AmazonRedshiftODBC-64-bit-1.4.59.1000-1.x86_64.rpm
odbcinst -i -d -f /opt/amazon/redshiftodbc/Setup/odbcinst.ini

