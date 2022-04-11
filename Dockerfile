FROM amazonlinux:2

ARG clamav_version=0.103.3

RUN amazon-linux-extras install -y python3.8
RUN ln -f /usr/bin/python3.8 /usr/bin/python3 && ln -f /usr/bin/pip3.8 /usr/bin/pip3

# Install packages
RUN yum update -y
RUN yum install -y cpio yum-utils zip unzip less libcurl-devel binutils openssl openssl-devel wget tar && yum groupinstall -y "Development Tools"

# Set up working directories
RUN mkdir -p /var/task/bin/
RUN mkdir -p /var/task/sbin/
RUN mkdir -p /var/task/etc/
RUN mkdir -p /var/task/lib/

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

WORKDIR /tmp
#clamav-devel
RUN yumdownloader -x \*i686 --archlist=x86_64 clamav clamav-lib clamav-update clamav-server clamav-data clamav-filesystem json-c pcre2 libprelude gnutls libtasn1 lib64nettle nettle
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -vimd
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio clamd*.rpm | cpio -idmv
RUN rpm2cpio clamav-filesystem*.rpm | cpio -idmv
#RUN rpm2cpio clamav-devel*.rpm | cpio -idmv
RUN rpm2cpio clamav-data*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio *.rpm | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/bin/clamdscan /var/task/bin/
RUN cp /tmp/usr/lib64/* /var/task/lib/
RUN cp /tmp/usr/sbin/* /var/task/sbin/

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
WORKDIR /var/task
COPY requirements.txt /var/task/requirements.txt
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /var/task/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /var/task/bin/freshclam.conf
RUN echo "DatabaseDirectory /tmp/clamav_defs" > /var/task/etc/clamd.conf
RUN echo "PidFile /tmp/clamd.pid" >> /var/task/etc/clamd.conf
RUN echo "LocalSocket /tmp/clamd.sock" >> /var/task/etc/clamd.conf
RUN echo "LogFile /tmp/clamd.log" >> /var/task/etc/clamd.conf

# Copy Python code into lambda
COPY ./*.py /var/task/

# Create the zip file
RUN zip -r9 --exclude="*test*" /lambda.zip *.py bin sbin etc lib

WORKDIR /usr/local/lib/python3.8/site-packages
RUN zip -r9 /lambda.zip *

RUN mv /lambda.zip /var/task/