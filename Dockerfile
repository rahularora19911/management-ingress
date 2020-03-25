# Dockerfile - alpine
# https://github.com/openresty/docker-openresty

ARG RESTY_IMAGE_BASE="alpine"
ARG RESTY_IMAGE_TAG="latest"

#FROM ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG}
FROM registry.access.redhat.com/ubi7/ubi:7.7 AS openresty_base
LABEL maintainer="Evan Wies <evan@neomantra.net>"

# Docker Build Arguments
ARG PREFIX_DIR="/opt/ibm/router"
ARG RESTY_VERSION="1.13.6.2"
ARG RESTY_OPENSSL_VERSION="1.0.2t"
ARG RESTY_OPENSSL_FIPS_VERSION="fips-2.0.16"
ARG RESTY_PCRE_VERSION="8.42"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_CONFIG_OPTIONS_MORE="--prefix=${PREFIX_DIR}"

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-luajit --with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"
ARG _RESTY_CONFIG_DEPS_FIPS="--with-luajit --with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} --with-openssl-opt=fips"

COPY docker/openresty/1.13.6.2/fips-code/Makefile /tmp/Makefile
COPY docker/openresty/1.13.6.2/fips-code/ngx_event_openssl.c /tmp/ngx_event_openssl.c

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Build OpenResty FIPS mode
# 5) Cleanup

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
RUN yum install --skip-broken -y wget \
        curl \
        perl \
        libxslt-devel \
        linux-headers \
        make \
        perl-devel \
        zlib-devel \
        file \
        gd \
        libgcc \
        libxslt \
        zlib \
        gcc \
        gcc-c++ \
        fontconfig-devel \
        freetype-devel \
        libX11-devel \
        libXpm-devel \
        libjpeg-devel libpng-devel \
# backup ubi release info
        && mkdir /tmp/release && mv /etc/*release* /tmp/release \
        && rpm -Uvh --force http://mirror.centos.org/centos-7/7/os/x86_64/Packages/centos-release-7-7.1908.0.el7.centos.x86_64.rpm && sed -i 's/$releasever/7/g' /etc/yum.repos.d/* \
    && yum install --skip-broken -y GeoIP-devel \
        ncurses-devel \
        readline-devel \
        kernel-devel \
        gd-devel \
# recovery ubi release info
        && rm /etc/*release* && mv /tmp/release/* /etc/ && rm -rf /tmp/release \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_FIPS_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_FIPS_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_FIPS_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
# 3) Build OpenResty
    && cd /tmp/openresty-${RESTY_VERSION} \
    && sed -ire "s/openresty/server/g" `find ./ -name ngx_http_special_response.c` \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && mv /opt/ibm/router/nginx/sbin/nginx /opt/ibm/router/nginx/sbin/nginx-nofips \
# 4) Build OpenResty FIPS mode
    && cd /tmp \
    && rm -rf /tmp/openssl-${RESTY_OPENSSL_VERSION} \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && rm -rf /tmp/openresty-${RESTY_VERSION} \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openssl-${RESTY_OPENSSL_FIPS_VERSION} \
    && ./config \
    && make \
    && make install \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && sed -ire "s/openresty/server/g" `find ./ -name ngx_http_special_response.c` \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS_FIPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && sed -i 's/pthread/& -lcrypt/g' /tmp/Makefile \
    && mv /tmp/Makefile /tmp/openresty-${RESTY_VERSION}/build/nginx-1.13.6/objs/Makefile \
    && mv /tmp/ngx_event_openssl.c /tmp/openresty-${RESTY_VERSION}/build/nginx-1.13.6/src/event/ngx_event_openssl.c \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && mv /opt/ibm/router/nginx/sbin/nginx /opt/ibm/router/nginx/sbin/nginx-fips \
    && ln -sf /opt/ibm/router/nginx/sbin/nginx-fips /opt/ibm/router/bin/openresty-fips \
    && mv /opt/ibm/router/nginx/sbin/nginx-nofips /opt/ibm/router/nginx/sbin/nginx \
    && ln -sf /opt/ibm/router/nginx/sbin/nginx /opt/ibm/router/bin/openresty \
# 5) Cleanup
    && yum clean all \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openssl-${RESTY_OPENSSL_FIPS_VERSION} \
        openssl-${RESTY_OPENSSL_FIPS_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    && ln -sf /dev/stdout ${PREFIX_DIR}/nginx/logs/access.log \
    && ln -sf /dev/stderr ${PREFIX_DIR}/nginx/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:${PREFIX_DIR}/luajit/bin:${PREFIX_DIR}/nginx/sbin:${PREFIX_DIR}/bin

# Copy nginx configuration files
# COPY nginx.conf ${PREFIX_DIR}/nginx/conf/nginx.conf

# CMD ["${PREFIX_DIR}/bin/openresty", "-g", "daemon off;"]

FROM openresty_base

ARG VCS_REF
ARG VCS_URL
ARG IMAGE_NAME
ARG IMAGE_DESCRIPTION
ARG IMAGE_VENDOR
ARG IMAGE_SUMMARY
# http://label-schema.org/rc1/
LABEL org.label-schema.vendor="IBM" \
      org.label-schema.name="$IMAGE_NAME" \
      org.label-schema.description="$IMAGE_DESCRIPTION" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.license="Licensed Materials - Property of IBM" \
      org.label-schema.schema-version="1.0" \
      name="$IMAGE_NAME" \
      vendor="$IMAGE_VENDOR" \
      description="$IMAGE_DESCRIPTION" \
      summary="$IMAGE_SUMMARY"

ENV AUTH_ERROR_PAGE_DIR_PATH=/opt/ibm/router/nginx/conf/errorpages SECRET_KEY_FILE_PATH=/etc/cfc/conf/auth-token-secret OIDC_ENABLE=false ADMINROUTER_ACTIVATE_AUTH_MODULE=true PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/ibm/router/nginx/sbin

RUN yum update -y --exclude=GeoIP* --exclude=readline* \
  && yum install -y  openssl python python-devl \
  && curl -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo -sSL https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo \
  && yum install -y dumb-init \
  && rpm -e kernel-devel \
  && yum clean all \
  && mkdir -p /var/log/nginx \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

COPY rootfs /

ADD packages.yaml License.txt /licenses/

ENTRYPOINT ["/usr/bin/dumb-init"]

CMD ["/management-ingress"]
