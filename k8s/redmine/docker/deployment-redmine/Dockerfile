FROM docker.io/bitnami/minideb:buster
LABEL maintainer "Bitnami <containers@bitnami.com>"

ENV HOME="/" \
    OS_ARCH="amd64" \
    OS_FLAVOUR="debian-10" \
    OS_NAME="linux"

COPY prebuildfs /
# Install required system packages and dependencies
RUN install_packages acl ca-certificates curl ghostscript gsfonts gzip imagemagick libaudit1 libbsd0 libc6 libcap-ng0 libcom-err2 libcurl4 libedit2 libffi6 libgcc1 libgcrypt20 libgmp-dev libgmp10 libgnutls30 libgpg-error0 libgssapi-krb5-2 libhogweed4 libicu63 libidn2-0 libjemalloc2 libk5crypto3 libkeyutils1 libkrb5-3 libkrb5support0 libldap-2.4-2 liblzma5 libmariadb3 libncurses6 libnettle6 libnghttp2-14 libp11-kit0 libpam0g libpq5 libpsl5 libreadline-dev libreadline7 librtmp1 libsasl2-2 libssh2-1 libssl-dev libssl1.1 libstdc++6 libtasn1-6 libtinfo6 libunistring2 libuuid1 libxml2 libxml2-dev libxslt1-dev libxslt1.1 procps sqlite3 tar zlib1g zlib1g-dev build-essential default-libmysqlclient-dev libpq-dev libmagickwand-dev
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "yq" "3.4.1-0" --checksum c88c76a7b5214407821771e5fc340f0320d5ded19eada938629603a982b8b640
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "ruby" "2.7.4-0" --checksum a9b3abf981ec41078e6975e5d5df5e5c5f5ed5b84ad0f9d679b4ee4c4a4f8d7c
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "postgresql-client" "11.12.0-0" --checksum 94395af20a0ee9e12aaab0d1a58bb42290145af8ab7f736c4bb7cc3f51bbf2b6
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "mysql-client" "10.4.20-0" --checksum 85d9e5d8f92e8aac0cdc8a17d09e1887fa1b11d5e5319a66093a4e933b73ac8c
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "git" "2.32.0-0" --checksum 3094f50c904e966bd6c6a2d6152cf41fd3a816d32395622a785ccbcda62b7c5f
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "redmine" "4.2.1-3" --checksum 18379553490a75d8f852ec345e6a2f36e6a4e1fea67fc798492f74897e8710a3
RUN . /opt/bitnami/scripts/libcomponent.sh && component_unpack "gosu" "1.13.0-0" --checksum fd7257c2736164d02832dbf72e2c1ed9d875bf3e32f0988520796bc503330129
COPY redmine_agile           /opt/bitnami/redmine/plugins/redmine_agile
COPY redmine_checklists      /opt/bitnami/redmine/plugins/redmine_checklists
COPY redmine_social_sign_in  /opt/bitnami/redmine/plugins/redmine_social_sign_in
COPY redmine_gitlab_adapter  /opt/bitnami/redmine/plugins/redmine_gitlab_adapter
RUN chmod g+rwX /opt/bitnami


COPY rootfs /
RUN /opt/bitnami/scripts/mysql-client/postunpack.sh
RUN /opt/bitnami/scripts/redmine/postunpack.sh
ENV ALLOW_EMPTY_PASSWORD="yes" \
    BITNAMI_APP_NAME="redmine" \
    BITNAMI_IMAGE_VERSION="4.2.1-debian-10-r75" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/ruby/bin:/opt/bitnami/postgresql/bin:/opt/bitnami/mysql/bin:/opt/bitnami/git/bin:$PATH" \
    ALLOW_EMPTY_PASSWORD=yes \
    POSTGRESQL_HOST="postgresql" \
    POSTGRESQL_PORT_NUMBER="5432" \
    POSTGRESQL_ROOT_PASSWORD="" \
    POSTGRESQL_ROOT_USER="postgres"

WORKDIR /opt/bitnami/redmine

RUN bundle config unset deployment
#RUN bundle install --without development test
RUN gem install bundler:2.2.23
RUN bundle install
RUN bundle exec rake generate_secret_token

EXPOSE 3000

USER root
ENTRYPOINT [ "/opt/bitnami/scripts/redmine/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/redmine/run.sh" ]

