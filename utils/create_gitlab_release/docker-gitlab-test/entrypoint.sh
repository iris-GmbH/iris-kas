#!/bin/sh

set -x

/assets/wrapper &

# wait for gitlab to be ready
healthy="1"
while test "$healthy" -ne 0; do
  /opt/gitlab/bin/gitlab-healthcheck --fail --max-time 10
  healthy=$?
  sleep 30
done

# create personal access token for testing
gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:api], name: 'GitLab Test Token', expires_at: 365.days.from_now); token.set_token('devtoken'); token.save!"

# keep alive
tail -f /dev/null
