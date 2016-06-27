FROM ubuntu:14.04
MAINTAINER  Grant Heffernan <grant@mapzen.com>

ENV TERM xterm
ENV BASEDIR /valhalla
ENV ENVIRONMENT ${ENVIRONMENT:-"dev"}
ENV TOOLS_BRANCH ${TOOLS_BRANCH:-"master"}
ENV MJOLNIR_BRANCH ${MJOLNIR_BRANCH:-"master"}
ENV VALHALLA_GITHUB ${VALHALLA_GITHUB:-"https://github.com/valhalla"}

RUN mkdir -p ${BASEDIR}
WORKDIR ${BASEDIR}
RUN mkdir tiles logs src locks extracts temp elevation data

ADD ./conf ${BASEDIR}/conf

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
  jq \
  git \
  curl \
  sudo \
  pigz \
  osmosis \
  parallel \
  osmctools \
  python-pip \
  spatialite-bin \
  software-properties-common

RUN pip install --upgrade pip
RUN pip install boto filechunkio awscli

# build or install from ppa
cd ${BASEDIR}/src && rm -rf ./*

RUN git clone --depth=1 --recurse-submodules --single-branch --branch=${MJOLNIR_BRANCH} ${VALHALLA_GITHUB}/mjolnir
RUN git clone --depth=1 --recurse-submodules --single-branch --branch=${TOOLS_BRANCH} ${VALHALLA_GITHUB}/tools

WORKDIR ${BASEDIR}/src/mjolnir
RUN scripts/dependencies.sh ${BASEDIR}/src
RUN scripts/install.sh
RUN make -j2 && make -j2 install

WORKDIR ${BASEDIR}/src/tools
RUN scripts/dependencies.sh ${BASEDIR}/src
RUN scripts/install.sh
RUN make -j2 && make -j2 install

ldconfig

# the assumption here is that data will be furnished through some other method.
#   If there is none, get something to test with.
WORKDIR ${BASEDIR}/data
RUN if [ $(ls ${BASEDIR}/data | wc -l) = 0 ]; then curl -O https://s3.amazonaws.com/metro-extracts.mapzen.com/trento_italy.osm.pbf; fi

# prep data
RUN valhalla_build_admins -c ${BASEDIR}/conf/valhalla.json ${BASEDIR}/data/*.pbf
RUN valhalla_build_tiles -c ${BASEDIR}/conf/valhalla.json ${BASEDIR}/data/*.pbf

# cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# run the service
EXPOSE 8080
CMD ["valhalla_route_service", "/valhalla/conf/valhalla.json"]
