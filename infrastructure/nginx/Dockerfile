FROM nginx:alpine

# Cần envsubst để render template (.conf.template → .conf)
# Cần openssl để generate dhparams nếu chưa có
RUN apk add --no-cache bash gettext openssl

# Xoá default config của image nginx
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy global nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Copy các template (dev/prod)
COPY templates /etc/nginx/templates

# Copy entrypoint để render template rồi chạy nginx
COPY entrypoint.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh

EXPOSE 80 443

CMD ["/docker-entrypoint-custom.sh"]
