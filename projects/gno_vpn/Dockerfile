FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/cache/nginx \
 && chown -R nginx:nginx /var/cache/nginx

