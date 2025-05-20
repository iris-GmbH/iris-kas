FROM gitlab/gitlab-ee:18.0.0-ee.0

ADD ./omnibus_config.rb /omnibus_config.rb
ADD ./entrypoint.sh /entrypoint.sh
ENV GITLAB_OMNIBUS_CONFIG="from_file('/omnibus_config.rb')"
EXPOSE 8000
CMD ["/entrypoint.sh"]
