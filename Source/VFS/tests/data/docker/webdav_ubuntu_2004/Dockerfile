FROM ubuntu:20.04

RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install apache2 -y
RUN a2enmod dav
RUN a2enmod dav_fs
RUN mkdir /var/www/webdav
RUN chmod 777 /var/www/webdav
RUN htpasswd -cb /etc/apache2/.htpasswd r2d2 Hello
RUN apt clean

COPY 000-default.conf /etc/apache2/sites-available/

EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]