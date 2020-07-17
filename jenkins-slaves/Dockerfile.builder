FROM ubuntu:18.04

LABEL maintainer="Santiago Sales <santiman625@gmail.com>"

# Make sure the package repository is up to date.
RUN apt update && \
    apt-get install -qy git
# Install a basic SSH server
RUN apt-get install -qy openssh-server && \
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd && \
    mkdir -p /var/run/sshd

# Install JDK 8
RUN apt-get install -qy openjdk-8-jdk

# Cleanup old packages
RUN apt-get -qy autoremove

# Add user jenkins to the image and set its password
RUN adduser --quiet jenkins && \
    echo "jenkins:jenkins" | chpasswd

# create a home directory
RUN mkdir /home/jenkins/.ssh
RUN chown -R jenkins:jenkins /home/jenkins/.ssh

# Standard SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]