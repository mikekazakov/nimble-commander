FROM alpine:3.21

RUN apk add --no-cache openssh shadow

# Generate host keys
RUN ssh-keygen -A

# Raise connection limits and disable the OpenSSH 9.9 per-source penalty system.
# The penalty system (new in OpenSSH 9.9) blacklists the Docker bridge IP when
# integration tests open many concurrent connections, blocking all subsequent tests.
RUN echo "MaxStartups 100" >> /etc/ssh/sshd_config && \
    echo "MaxSessions 100" >> /etc/ssh/sshd_config && \
    echo "PerSourcePenalties no" >> /etc/ssh/sshd_config

# Restrict user6 to SFTP only
RUN echo "Match User user6" >> /etc/ssh/sshd_config && \
    echo "    ForceCommand internal-sftp" >> /etc/ssh/sshd_config

# A fixed-content file for testing file reads over SFTP
RUN echo -n "alpine_sftp_test" > /etc/nc_sftp_test

# Root user: ED25519 key (same key as user4)
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzhtvvYnsNgzpQ0ozeRX7jboCFKBWHMbElsdCBM4Up+ foo@bar.local" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# user1: password only
RUN useradd --create-home --shell /bin/sh user1 && \
    echo 'user1:Oc6har5tOu34' | chpasswd

# user2: RSA key
RUN useradd --create-home --shell /bin/sh user2 && \
    echo 'user2:_key_auth_only_2!' | chpasswd && \
    mkdir -p /home/user2/.ssh && \
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD2EQcOueD0hfKS2HYFWeCaUwaAkh9+B/fpShMBdKFyXOirO/yjr8HFnnqGJ+QoIlYNHCermlD4L50HTNvERosMq8Cz1dptkLJLLoQFRoPRCH7oBBp53FwiXFcEJdsuEhUiq4VE2a1Wen/J15P3dp57moj7MB4GvKrfSxs5/fLYXD1v4l663zfNvPOzYP0T6JJiaTEQzTXw9Ft5Oo9u39wEteXvMEhE/dnMzC5qo/18dBp9c6S7dei4v5UdkJoOxNVCnWgPM9GxrCP+SSGXD+2vBe9m4E8qW+4g3LZQyIkoyRYBjWnLLgR63mW43yxq+evdoiTJ8A4RTQzRu2/sqhC3sTJ/SS6dCShlFtxbJP8bBGc2qanS1htQfrMrIBqRYdfM9Ty/vkr1iFkuXkuYduSc+e/8fByi9Au7FWYmSG98bxrL/rhbaSnN+sqouS0U4VvcDq9xoxQgY/OP9zohyvK8x19wgiROOhmwNda3CWXfPO6VM+qM6aTKigIm6nozlfc= foo@bar.local" >> /home/user2/.ssh/authorized_keys && \
    chown -R user2:user2 /home/user2/.ssh && chmod 700 /home/user2/.ssh && chmod 600 /home/user2/.ssh/authorized_keys

# user3: ECDSA key
RUN useradd --create-home --shell /bin/sh --password '*' user3 && \
    mkdir -p /home/user3/.ssh && \
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLzXafu9WVj1Tqo5X/s5KNXnZkSuz+WN0QJjYyDXxr4tW8hSmOaGNQ8xatwO792ju6NlE3VMgLfAo6u7CCOe5HQ= foo@bar.local" >> /home/user3/.ssh/authorized_keys && \
    chown -R user3:user3 /home/user3/.ssh && chmod 700 /home/user3/.ssh && chmod 600 /home/user3/.ssh/authorized_keys

# user4: ED25519 key
RUN useradd --create-home --shell /bin/sh user4 && \
    echo 'user4:_key_auth_only_4!' | chpasswd && \
    mkdir -p /home/user4/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzhtvvYnsNgzpQ0ozeRX7jboCFKBWHMbElsdCBM4Up+ foo@bar.local" >> /home/user4/.ssh/authorized_keys && \
    chown -R user4:user4 /home/user4/.ssh && chmod 700 /home/user4/.ssh && chmod 600 /home/user4/.ssh/authorized_keys

# user6: SFTP-only (ForceCommand internal-sftp), password
RUN useradd --create-home --shell /bin/sh user6 && \
    echo 'user6:QPC89AM!SPk9' | chpasswd

# user7: password-protected RSA key
RUN useradd --create-home --shell /bin/sh user7 && \
    echo 'user7:_key_auth_only_7!' | chpasswd && \
    mkdir -p /home/user7/.ssh && \
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCuLHsJEjeLecWFlRuLgnkFL5A1KL1r+/L2RLyuF0vcWeD3ZmBL/H1vUgKko3THbKG+kkYXnl9B6REemBHfrxCqCkibOVW6s9BPhPjkIKaMNbeBKAPbK02+1eHyAAsiiiFbs6OIHL6G1VyeMKyG2TxDMaxIW4YYOL8hZ4/Wjy2pN49EKAj15xwCmn3gkL+kMrwiAigXj7uUWw7W/mY6ysbmpMf2MwwxV2PrrPyRgl6mKma4VJk70xNL6ZuxYz5Hr6mUMXSOE+NphqbqazxjlVWeGmuODjr6A3oRSzwnlFj3KSFjUp60Nb18ROY/5Y1wcTp4fOi8g9BkHgGffBKDjJp8rZlvJ9JzKDNPwM9RW5hloXY4sQRZJ6uAf61GaZO0u7lBGrvNWFTLzbjzieJ0mVwm0kmgEcL6VVFDwztqgYziWsw4IEgIfaHd9yuQXPJKOJY/kTkVyUh/p8Wlh1yqHjXEIb9FtW+4zIZT3JHcFfsSa3tGtQHj+FuVgcCWDvbN4Ls= foo@bar.local" >> /home/user7/.ssh/authorized_keys && \
    chown -R user7:user7 /home/user7/.ssh && chmod 700 /home/user7/.ssh && chmod 600 /home/user7/.ssh/authorized_keys

# user8: password-protected ECDSA key
RUN useradd --create-home --shell /bin/sh user8 && \
    echo 'user8:_key_auth_only_8!' | chpasswd && \
    mkdir -p /home/user8/.ssh && \
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHCQH8BJn7QKBnPizD+fmM6RNbhpGGpPZ+YaMmCxCx2hI/UN6k9mKEMhiaPxUSfpcJjq2Qj/jkTcKzOA5GgraO0= foo@bar.local" >> /home/user8/.ssh/authorized_keys && \
    chown -R user8:user8 /home/user8/.ssh && chmod 700 /home/user8/.ssh && chmod 600 /home/user8/.ssh/authorized_keys

# user9: password-protected ED25519 key
RUN useradd --create-home --shell /bin/sh user9 && \
    echo 'user9:_key_auth_only_9!' | chpasswd && \
    mkdir -p /home/user9/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEVyr5jry9GdvxXO5IySySIWmJbyglBLfrxaorba+wfE foo@bar.local" >> /home/user9/.ssh/authorized_keys && \
    chown -R user9:user9 /home/user9/.ssh && chmod 700 /home/user9/.ssh && chmod 600 /home/user9/.ssh/authorized_keys

EXPOSE 22

ENTRYPOINT ["/usr/sbin/sshd", "-D", "-e"]
