FROM ubuntu:20.04

RUN apt update && \
    apt-get -y install openssh-server && \
    mkdir -p /var/run/sshd

RUN echo "PubkeyAcceptedKeyTypes=+ssh-dss" >> /etc/ssh/sshd_config.d/my.conf

RUN echo "Match User user6" >> /etc/ssh/sshd_config && \
    echo "    ForceCommand internal-sftp" >> /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzhtvvYnsNgzpQ0ozeRX7jboCFKBWHMbElsdCBM4Up+ foo@bar.local" >> /root/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user1 && \
    echo 'user1:Oc6har5tOu34' | chpasswd

RUN useradd --create-home --shell /bin/bash user2 && \
    mkdir -p /home/user2/.ssh && \
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD2EQcOueD0hfKS2HYFWeCaUwaAkh9+B/fpShMBdKFyXOirO/yjr8HFnnqGJ+QoIlYNHCermlD4L50HTNvERosMq8Cz1dptkLJLLoQFRoPRCH7oBBp53FwiXFcEJdsuEhUiq4VE2a1Wen/J15P3dp57moj7MB4GvKrfSxs5/fLYXD1v4l663zfNvPOzYP0T6JJiaTEQzTXw9Ft5Oo9u39wEteXvMEhE/dnMzC5qo/18dBp9c6S7dei4v5UdkJoOxNVCnWgPM9GxrCP+SSGXD+2vBe9m4E8qW+4g3LZQyIkoyRYBjWnLLgR63mW43yxq+evdoiTJ8A4RTQzRu2/sqhC3sTJ/SS6dCShlFtxbJP8bBGc2qanS1htQfrMrIBqRYdfM9Ty/vkr1iFkuXkuYduSc+e/8fByi9Au7FWYmSG98bxrL/rhbaSnN+sqouS0U4VvcDq9xoxQgY/OP9zohyvK8x19wgiROOhmwNda3CWXfPO6VM+qM6aTKigIm6nozlfc= foo@bar.local" >> /home/user2/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user3 && \
    mkdir -p /home/user3/.ssh && \
    echo "ssh-dss AAAAB3NzaC1kc3MAAACBAIkgtkkH8xz3C5KU3QGGCNs2giAEg2yRJsrNB4SFaX4JAigV1QOHtNiJYs+uggJDY7UfX/ulbcjcS0ABb9f+x8ERg0yLsbIEjNSYMJnmLkYrSnsSGGyx7v4bELW3LYvU89FHyq/Vw9A+XQ+MyC84ucew98NRYY3b058YDppqhx9rAAAAFQCCLasncYa/UDzyMjeYdM8gQoy5GQAAAIAbaxf7yaKAclK1U1gHClxkfWFpiS1M4py0rbTgJEqFcSgByYTqtAPg+2JBoZwbXF1XIXUxekOvXBiH+oEa3ZVhi81lg8eCzLaaR0npmOCGTQFfHAWo2eHiQJ9CiYV4bwMcQFceHah9RSTrgl3WVXVqJazso1P482VclU2zgltoGAAAAIB0T0Uf87qIItBZmsJJZ+gj7mjxAkiDFx7tpEoEZ75ahXBn18luFRE3ON1hPhKUsx9EbZ8IGw7mtDbfpKjaF44csp0qC99A4cXiC1ZPRtoYwxsW7xrp7Oj/uOExRvors0MzqGobi2SVD1eDbRuiU1sPS7ZS+fUGwsAv/MLx1haQwA== foo@bar.local" >> /home/user3/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user4 && \
    mkdir -p /home/user4/.ssh && \
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLzXafu9WVj1Tqo5X/s5KNXnZkSuz+WN0QJjYyDXxr4tW8hSmOaGNQ8xatwO792ju6NlE3VMgLfAo6u7CCOe5HQ= foo@bar.local" >> /home/user4/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user5 && \
    mkdir -p /home/user5/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzhtvvYnsNgzpQ0ozeRX7jboCFKBWHMbElsdCBM4Up+ foo@bar.local" >> /home/user5/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user6 && \
    echo 'user6:QPC89AM!SPk9' | chpasswd
    
RUN useradd --create-home --shell /bin/bash user7 && \
    mkdir -p /home/user7/.ssh && \
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCuLHsJEjeLecWFlRuLgnkFL5A1KL1r+/L2RLyuF0vcWeD3ZmBL/H1vUgKko3THbKG+kkYXnl9B6REemBHfrxCqCkibOVW6s9BPhPjkIKaMNbeBKAPbK02+1eHyAAsiiiFbs6OIHL6G1VyeMKyG2TxDMaxIW4YYOL8hZ4/Wjy2pN49EKAj15xwCmn3gkL+kMrwiAigXj7uUWw7W/mY6ysbmpMf2MwwxV2PrrPyRgl6mKma4VJk70xNL6ZuxYz5Hr6mUMXSOE+NphqbqazxjlVWeGmuODjr6A3oRSzwnlFj3KSFjUp60Nb18ROY/5Y1wcTp4fOi8g9BkHgGffBKDjJp8rZlvJ9JzKDNPwM9RW5hloXY4sQRZJ6uAf61GaZO0u7lBGrvNWFTLzbjzieJ0mVwm0kmgEcL6VVFDwztqgYziWsw4IEgIfaHd9yuQXPJKOJY/kTkVyUh/p8Wlh1yqHjXEIb9FtW+4zIZT3JHcFfsSa3tGtQHj+FuVgcCWDvbN4Ls= foo@bar.local" >> /home/user7/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user8 && \
    mkdir -p /home/user8/.ssh && \
    echo "ssh-dss AAAAB3NzaC1kc3MAAACBAM+0BkbiP1JyuaDl5Us/4xAmuiT8BYGMBgCiAeEuXL/6IzYq1WSrPjSipKZbt9+fPgTY6aVLLCPEaU5I3I5Rk6arELD/EOkAyZGaquPpXqZr+fVS9kYdpWOYdpjF0k0oCpbpAsBXvtThAMQjLwTSNTyq7nh7qJZk2EMvoBMGSlHfAAAAFQCQYDJ/8QQIxw8tWIWzGxMSLY7JgwAAAIEAoMWDAd55CH73gKwBZTPhQFSg7WdYG+QxkySefBrG0SHF5c82wGFlhRC5hICq5vv9+C57BPT1FeemNfekXg1QkO4e7QYX9ro7OW9SVRghP23NVOetwKU0J8SnriGptXvXALQLXLyamkzwEetGzIfesOEHfRGQuo+7XQTQ4q5rDAYAAACBAMrvlHLGJpVudfxVvsF1Z51RWXLQJWqx04vAqJcsc52Fy+p46EinmdPRdCpWd1z+TNktwW3/pgPxd+6GYF/H6c8Psep2SSwMgxzJwRMeqmX3qT9MUWok6FFcLyIuRjr7JOLghTmYND0sGmL2heCcT/B/BHHMAOjyAZbzYVf4xeWN foo@bar.local" >> /home/user8/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user9 && \
    mkdir -p /home/user9/.ssh && \
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHCQH8BJn7QKBnPizD+fmM6RNbhpGGpPZ+YaMmCxCx2hI/UN6k9mKEMhiaPxUSfpcJjq2Qj/jkTcKzOA5GgraO0= foo@bar.local" >> /home/user9/.ssh/authorized_keys

RUN useradd --create-home --shell /bin/bash user10 && \
    mkdir -p /home/user10/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEVyr5jry9GdvxXO5IySySIWmJbyglBLfrxaorba+wfE foo@bar.local" >> /home/user10/.ssh/authorized_keys

EXPOSE 22

ENTRYPOINT /usr/sbin/sshd -D -e
