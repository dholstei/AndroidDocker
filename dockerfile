#   CentOS 9
FROM moongeun/centos9

ARG SCRIPT=android_env.sh

#   Setup OS and updates
RUN yum update -y
RUN yum install -y freetype xterm xhost libXtst qemu-kvm libvirt nss libxkbfile net-tools openssh-server
RUN yum update -y

#   Copy Android-Studio script
RUN mkdir -p /root/bin
COPY avd.tar.xz skins.tar.xz /
RUN tar xvf avd.tar.xz -C /root;
RUN tar xvf skins.tar.xz -C /root;

RUN mkdir /var/run/sshd
# CMD ["/usr/sbin/sshd", "-D"]

#   Replicate user
ARG UID_ HOME_ SHELL_ USER_ FULLNAME
RUN useradd -r -u $UID_ -m -d $HOME_ -s $SHELL_ -c "$FULLNAME" $USER_
COPY $SCRIPT /
