FROM ubuntu:20.04

RUN apt update && \
    apt-get -y install openssh-server && \
    mkdir -p /var/run/sshd

RUN echo "PubkeyAcceptedKeyTypes=+ssh-dss" >> /etc/ssh/sshd_config.d/my.conf

RUN useradd --create-home --shell /bin/bash user1 && \
    echo 'user1:Oc6har5tOu34' | chpasswd

RUN useradd --create-home --shell /bin/bash user2 && \
    echo 'user2:38e^&HRwajat' | chpasswd
RUN mkdir -p /home/user2/.ssh/
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD2EQcOueD0hfKS2HYFWeCaUwaAkh9+B/fpShMBdKFyXOirO/yjr8HFnnqGJ+QoIlYNHCermlD4L50HTNvERosMq8Cz1dptkLJLLoQFRoPRCH7oBBp53FwiXFcEJdsuEhUiq4VE2a1Wen/J15P3dp57moj7MB4GvKrfSxs5/fLYXD1v4l663zfNvPOzYP0T6JJiaTEQzTXw9Ft5Oo9u39wEteXvMEhE/dnMzC5qo/18dBp9c6S7dei4v5UdkJoOxNVCnWgPM9GxrCP+SSGXD+2vBe9m4E8qW+4g3LZQyIkoyRYBjWnLLgR63mW43yxq+evdoiTJ8A4RTQzRu2/sqhC3sTJ/SS6dCShlFtxbJP8bBGc2qanS1htQfrMrIBqRYdfM9Ty/vkr1iFkuXkuYduSc+e/8fByi9Au7FWYmSG98bxrL/rhbaSnN+sqouS0U4VvcDq9xoxQgY/OP9zohyvK8x19wgiROOhmwNda3CWXfPO6VM+qM6aTKigIm6nozlfc= foo@bar.local" >> /home/user2/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user3 && \
    echo 'user3:J!9dPSk*RB9v' | chpasswd
RUN mkdir -p /home/user3/.ssh/
RUN echo "ssh-dss AAAAB3NzaC1kc3MAAACBAIkgtkkH8xz3C5KU3QGGCNs2giAEg2yRJsrNB4SFaX4JAigV1QOHtNiJYs+uggJDY7UfX/ulbcjcS0ABb9f+x8ERg0yLsbIEjNSYMJnmLkYrSnsSGGyx7v4bELW3LYvU89FHyq/Vw9A+XQ+MyC84ucew98NRYY3b058YDppqhx9rAAAAFQCCLasncYa/UDzyMjeYdM8gQoy5GQAAAIAbaxf7yaKAclK1U1gHClxkfWFpiS1M4py0rbTgJEqFcSgByYTqtAPg+2JBoZwbXF1XIXUxekOvXBiH+oEa3ZVhi81lg8eCzLaaR0npmOCGTQFfHAWo2eHiQJ9CiYV4bwMcQFceHah9RSTrgl3WVXVqJazso1P482VclU2zgltoGAAAAIB0T0Uf87qIItBZmsJJZ+gj7mjxAkiDFx7tpEoEZ75ahXBn18luFRE3ON1hPhKUsx9EbZ8IGw7mtDbfpKjaF44csp0qC99A4cXiC1ZPRtoYwxsW7xrp7Oj/uOExRvors0MzqGobi2SVD1eDbRuiU1sPS7ZS+fUGwsAv/MLx1haQwA== foo@bar.local" >> /home/user3/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user4 && \
    echo 'user4:aVAt5JvQx0Mf' | chpasswd
RUN mkdir -p /home/user4/.ssh/
RUN echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLzXafu9WVj1Tqo5X/s5KNXnZkSuz+WN0QJjYyDXxr4tW8hSmOaGNQ8xatwO792ju6NlE3VMgLfAo6u7CCOe5HQ= foo@bar.local" >> /home/user4/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user5 && \
    echo 'user5:spl8FJbTg5Gk' | chpasswd
RUN mkdir -p /home/user5/.ssh/
RUN echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzhtvvYnsNgzpQ0ozeRX7jboCFKBWHMbElsdCBM4Up+ foo@bar.local" >> /home/user5/.ssh/authorized_keys

EXPOSE 22

ENTRYPOINT /usr/sbin/sshd -D -e
