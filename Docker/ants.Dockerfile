FROM verificarlo/verificarlo as builder

ENV DEBIAN_FRONTEND="noninteractive"

# ANTs requirements
RUN : \
    && apt-get update \
    && apt-get install -y \
    bc \
    cmake \
    git \
    software-properties-common \
    unzip \
    wget \
    zlib1g-dev \
    && :

# ANTs superbuild failed to build ITK with verificarlo. So, we build ITK externally.
# ITK paper-base.
ARG ITK_VERSION="paper-base"
RUN : \
    && git clone https://github.com/mathdugre/ITK.git /tmp/itk/source \
    && cd /tmp/itk/source \
    && git checkout ${ITK_VERSION} \
    && mkdir -p /tmp/itk/build \
    && :
# Configure ITK
RUN : \
    && cd /tmp/itk/build \
    && cmake \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DITK_LEGACY_REMOVE=ON \
    -DITK_FUTURE_LEGACY_REMOVE=OFF \
    -DITKV3_COMPATIBILITY=OFF \
    -DITK_BUILD_DEFAULT_MODULES=ON \
    -DKWSYS_USE_MD5=ON \
    -DITK_WRAPPING=OFF \
    -DModule_MGHIO=ON \
    -DModule_ITKReview=ON \
    -DModule_GenericLabelInterpolator=ON \
    -DModule_AdaptiveDenoising=ON \
    /tmp/itk/source \
    && :
# Build ITK
RUN : \
    && cd /tmp/itk/build \
    && make -j \
    && :
# Install ITK
RUN : \
    && cd /tmp/itk/build \
    && make install \
    && :

# ANTs paper-base with ITK verificarlo compilation.
ARG ANTs_VERSION="paper-base"
RUN : \
    && git clone https://github.com/mathdugre/ANTs.git /tmp/ants/source \
    && cd /tmp/ants/source \
    && git checkout ${ANTs_VERSION} \
    && mkdir -p /tmp/ants/build \
    && cd /tmp/ants/build \
    && mkdir -p /opt/ants \
    && git config --global url."https://".insteadOf git:// \
    && :
# Configure ANTs
RUN : \
    && cd /tmp/ants/build \
    && cmake \
    -DBUILD_TESTING=ON \
    -DRUN_LONG_TESTS=OFF \
    -DRUN_SHORT_TESTS=ON \
    -DCMAKE_INSTALL_PREFIX=/opt/ants \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DITK_DIR=/tmp/itk/build \
    -DUSE_SYSTEM_ITK=ON \
    /tmp/ants/source \
    && :
# Build ANTs
RUN : \
    && cd /tmp/ants/build \
    && make -j \
    && :
# Install ANTs
RUN : \
    && cd /tmp/ants/build/ANTS-build \
    && make install \
    && :

# Need to set library path to run tests
ENV LD_LIBRARY_PATH="/opt/ants/lib:$LD_LIBRARY_PATH"

RUN cd /tmp/ants/build/ANTS-build \
    && cmake --build . --target test

RUN wget https://ndownloader.figshare.com/files/3133832 -O oasis.zip \
    && unzip oasis.zip -d /opt \
    && rm -rf oasis.zip

FROM verificarlo/verificarlo
COPY --from=builder /opt/ants /opt/ants
COPY --from=builder /opt/MICCAI2012-Multi-Atlas-Challenge-Data /opt/templates/OASIS
COPY --from=builder /tmp/ants /tmp/ants
COPY --from=builder /tmp/itk /tmp/itk

ENV ANTSPATH="/opt/ants/bin" \
    PATH="/opt/ants/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ants/lib:$LD_LIBRARY_PATH"
RUN : \
    && apt-get update \
    && apt install -y --no-install-recommends \
    bc \
    zlib1g-dev \
    gdb \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && :

WORKDIR /data

CMD ["/bin/bash"]

