FROM ubuntu:20.04

RUN apt update && \
    apt-get -y install openssh-server && \
    mkdir -p /var/run/sshd

RUN useradd --create-home --shell /bin/bash user1 && \
    echo 'user1:Oc6har5tOu34' | chpasswd

RUN useradd --create-home --shell /bin/bash user2 && \
    echo 'user2:38e^&HRwajat' | chpasswd
RUN mkdir -p /home/user2/.ssh/
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD2EQcOueD0hfKS2HYFWeCaUwaAkh9+B/fpShMBdKFyXOirO/yjr8HFnnqGJ+QoIlYNHCermlD4L50HTNvERosMq8Cz1dptkLJLLoQFRoPRCH7oBBp53FwiXFcEJdsuEhUiq4VE2a1Wen/J15P3dp57moj7MB4GvKrfSxs5/fLYXD1v4l663zfNvPOzYP0T6JJiaTEQzTXw9Ft5Oo9u39wEteXvMEhE/dnMzC5qo/18dBp9c6S7dei4v5UdkJoOxNVCnWgPM9GxrCP+SSGXD+2vBe9m4E8qW+4g3LZQyIkoyRYBjWnLLgR63mW43yxq+evdoiTJ8A4RTQzRu2/sqhC3sTJ/SS6dCShlFtxbJP8bBGc2qanS1htQfrMrIBqRYdfM9Ty/vkr1iFkuXkuYduSc+e/8fByi9Au7FWYmSG98bxrL/rhbaSnN+sqouS0U4VvcDq9xoxQgY/OP9zohyvK8x19wgiROOhmwNda3CWXfPO6VM+qM6aTKigIm6nozlfc= foo@bar.local" >> /home/user2/.ssh/authorized_keys

EXPOSE 22

ENTRYPOINT /usr/sbin/sshd -D -e
