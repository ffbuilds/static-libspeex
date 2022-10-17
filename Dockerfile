
# bump: speex /SPEEX_VERSION=([\d.]+)/ https://github.com/xiph/speex.git|*
# bump: speex after ./hashupdate Dockerfile SPEEX $LATEST
# bump: speex link "ChangeLog" https://github.com/xiph/speex//blob/master/ChangeLog
# bump: speex link "Source diff $CURRENT..$LATEST" https://github.com/xiph/speex/compare/$CURRENT..$LATEST
ARG SPEEX_VERSION=1.2.1
ARG SPEEX_URL="https://github.com/xiph/speex/archive/Speex-$SPEEX_VERSION.tar.gz"
ARG SPEEX_SHA256=beaf2642e81a822eaade4d9ebf92e1678f301abfc74a29159c4e721ee70fdce0

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG SPEEX_URL
ARG SPEEX_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O speex.tar.gz "$SPEEX_URL" && \
  echo "$SPEEX_SHA256  speex.tar.gz" | sha256sum --status -c - && \
  mkdir speex && \
  tar xf speex.tar.gz -C speex --strip-components=1 && \
  rm speex.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/speex/ /tmp/speex/
WORKDIR /tmp/speex
RUN \
  apk add --no-cache --virtual build \
    build-base autoconf automake libtool pkgconf && \
  ./autogen.sh && \
  ./configure --disable-shared --enable-static && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path speex && \
  ar -t /usr/local/lib/libspeex.a && \
  readelf -h /usr/local/lib/libspeex.a && \
  # Cleanup
  apk del build

FROM scratch
ARG SPEEX_VERSION
COPY --from=build /usr/local/lib/pkgconfig/speex.pc /usr/local/lib/pkgconfig/speex.pc
COPY --from=build /usr/local/lib/libspeex.a /usr/local/lib/libspeex.a
COPY --from=build /usr/local/include/speex/ /usr/local/include/speex/
