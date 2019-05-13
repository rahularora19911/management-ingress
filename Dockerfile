FROM BASE_IMAGE

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

RUN yum update \
  && yum install -y  openssl python python-devl \
  && curl -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo -sSL https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo \
  && yum install -y dumb-init \
  && yum clean all \
  && mkdir -p /var/log/nginx \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

COPY rootfs /

ADD packages.yaml License.txt /licenses/

ENTRYPOINT ["/usr/bin/dumb-init"]

CMD ["/icp-management-ingress"]