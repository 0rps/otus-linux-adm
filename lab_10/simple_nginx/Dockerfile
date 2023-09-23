FROM alpine:3.18

RUN apk add --no-cache nginx vim mc
RUN mkdir -p /var/www/html
COPY default.conf /etc/nginx/http.d/default.conf
RUN echo "Hello world!" > /var/www/html/index.html

ENTRYPOINT [ "nginx" ]
CMD ["-g", "daemon off;"]