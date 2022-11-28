FROM artifactory.prod.tableautools.com:6555/library/centos:7
RUN yum -y update
COPY tableau-bridge-*.rpm .

RUN yum install -y $(find . -name tableau-bridge-*.rpm) && rm tableau-bridge-*.rpm
ENV JAVA_HOME=/opt/tableau/tableau_bridge/jre/

COPY AmazonRedshiftODBC-64-bit-1.4.59.1000-1.x86_64.rpm setup-redshift.sh ./
RUN /bin/bash -c ./setup-redshift.sh && rm AmazonRedshiftODBC-64-bit-1.4.59.1000-1.x86_64.rpm

COPY start-bridgeclient.sh .
CMD ["./start-bridgeclient.sh"]
