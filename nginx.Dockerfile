FROM nginx
RUN apt-get update -qq && apt-get -y install apache2-utils
ENV RAILS_ROOT /app
WORKDIR $RAILS_ROOT
RUN mkdir log
STOPSIGNAL SIGTERM
EXPOSE 80
COPY --from=publishing /app/public/assets /app/public/assets
COPY --from=publishing /app/public/packs /app/public/packs
CMD [ "nginx", "-g", "daemon off;" ]