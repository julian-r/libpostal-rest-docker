ARG CIRCLE_PROJECT_REPONAME=libpostal
ARG DOCKER_IMAGE=centos
ARG DOCKER_VERSION=latest
ARG VCS_REF
ARG BUILD_DATE=$("date -u")

FROM ${DOCKER_IMAGE}:${DOCKER_VERSION}

LABEL   Maintainer="support@clicksend.com" \
        Description="${DOCKER_IMAGE} container that handles ${CIRCLE_PROJECT_REPONAME} sevices." \
        org.label-schema.name="${CIRCLE_PROJECT_REPONAME}" \
        org.label-schema.description="${DOCKER_IMAGE} container that handles ${CIRCLE_PROJECT_REPONAME} sevices." \
        org.label-schema.build-date=$BUILD_DATE \
        org.label-schema.vcs-ref=$VCS_REF \
        org.label-schema.schema-version="1.0.0"

ENV DEBIAN_FRONTEND=interactive \
    GO_VERSION=${GO_VERSION:-"1.11.1"} \
    GOROOT=/libpostal/go \
    GOARCH=amd64 \
    GOOS=linux \
    GOPATH=/libpostal/workspace \
    LIBPOSTAL_DATA_DIR="/opt/libpostal_data" \
    PATH=$PATH:/libpostal/go/bin \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" \
    DOWNLOAD_LIBPOSTAL_DATA=${DOWNLOAD_LIBPOSTAL_DATA:-"true"}

# Install python 3.6.0 and pip3 and python-dev headers for pypostal
RUN yum -y update && \
    yum -y install curl autoconf automake libtool pkgconfig \
    gcc \
    make \
    git \
    wget \
    yum-utils \
    https://centos7.iuscommunity.org/ius-release.rpm

COPY *.sh /etc/

# install GNU parallel (for faster download of libpostal data)
RUN chmod +x /etc/*.sh && \
    /etc/install_parallel.sh

# Download latest libpostal data using parallel
RUN /etc/download_libpostal_data.sh

RUN yum -y install \
    python36u \
    python36u-devel \
    python36u-pip \
    postgresql \
    python-pip

# Install libpostal
RUN git clone https://github.com/openvenues/libpostal && \
    cd libpostal && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr --datadir=$LIBPOSTAL_DATA_DIR && \
    make && \
    sudo make install \
    sudo ldconfig

# Install pypostal (using python3)
RUN pip install --upgrade pip && \
    pip install postal \
        happybase \
        pandas \
        jsonschema \
        numpy \
        psycopg2 \
        SQLAlchemy \
        xlrd \
        matplotlib \
        scipy \
        statsmodels \
        patsy \
    	six && \
    pip install connexion --ignore-installed && \
    pip install flask --ignore-installed

# Create symlinks for the C objects (so we dont need to set LD_LIBRARY_PATH).
RUN ln -s /usr/lib/libpostal.a /usr/lib64/libpostal.a && \
    ln -s /usr/lib/libpostal.la /usr/lib64/libpostal.la && \
    ln -s /usr/lib/libpostal.so /usr/lib64/libpostal.so && \
    ln -s /usr/lib/libpostal.so.1 /usr/lib64/libpostal.so.1 && \
    ln -s /usr/lib/libpostal.so.1.0.0 /usr/lib64/libpostal.so.1.0.0

# Create a 'data' volume for mounting external post data
#VOLUME /data

# Create a 'source' volume for mounting external python source files.
VOLUME /src

COPY var/www/html/ /var/www/html
WORKDIR /var/www/html

# Start server
CMD ["python", "server.py"]
