# build stage goes base --> devel --> plugin
#Consolodating 3 Dockerfiles into a single build

#Begin base image build stage 1
#https://gitlab.com/nvidia/cuda/blob/centos7/9.1/base/Dockerfile

FROM registry.access.redhat.com/rhel7:latest
LABEL maintainer "NVIDIA CORPORATION <cudatools@nvidia.com>"

### Add Atomic/OpenShift Labels - https://github.com/projectatomic/ContainerApplicationGenericLabels#####
LABEL name="k8s-device-plugin" \
      vendor="Nvidia" \
      version="1.9" \
      release="1" \
      summary="The NVIDIA device plugin for Kubernetes" \
      description="Daemonset that allows you to automatically expose the number of GPUs on each nodes of your cluster,keep track of the health of your GPUs, run GPU enabled containers in your Kubernetes cluster." 

#Adding Licenses 
COPY licenses /licenses


#RUN NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
#    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
#    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -

#cuda.repo if from local repo to save bandwidth
COPY cuda.repo /etc/yum.repos.d/cuda.repo

ENV CUDA_VERSION 9.1.85

ENV CUDA_PKG_VERSION 9-1-$CUDA_VERSION-1
RUN yum install -y \
          cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-9.1 /usr/local/cuda
#    ln -s cuda-9.1 /usr/local/cuda && \
#    rm -rf /var/cache/yum/*


# nvidia-docker 1.0
LABEL com.nvidia.volumes.needed="nvidia_driver"
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=9.1"

#End base image build stage 1

#Begin devel stage 2
#https://gitlab.com/nvidia/cuda/blob/centos7/9.1/devel/Dockerfile

RUN yum install -y \
        cuda-libraries-dev-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION \
        cuda-minimal-build-$CUDA_PKG_VERSION \
        cuda-command-line-tools-$CUDA_PKG_VERSION
#        cuda-command-line-tools-$CUDA_PKG_VERSION && \
#    rm -rf /var/cache/yum/*

ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs:${LIBRARY_PATH}

#End devel stage 2

#Begin plugin stage 3
#https://github.com/NVIDIA/k8s-device-plugin/blob/v1.9/Dockerfile

RUN yum install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#    && yum clean all

RUN yum install -y \
        gcc \
        ca-certificates \
        wget \
        dkms

RUN yum install -y \
        cuda-cudart-dev-$CUDA_PKG_VERSION \
        cuda-misc-headers-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION 
       
ENV GOLANG_VERSION 1.9.4
RUN wget -nv -O - https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz \
  | tar -C /usr/local -xz
 

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

ENV CGO_CFLAGS "-I /usr/local/cuda-8.0/include"
ENV CGO_LDFLAGS "-L /usr/local/cuda-8.0/lib64"
ENV PATH=$PATH:/usr/local/nvidia/bin:/usr/local/cuda/bin

WORKDIR /go/src/nvidia-device-plugin
COPY . .

#RUN export CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' && \
 #   go install -ldflags="-s -w" -v nvidia-device-plugin
#RUN go install -v nvidia-device-plugin

#FROM debian:stretch-slim
#The above line shouldn't be needed. All utilities should be included

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=utility

#COPY --from=build /go/bin/nvidia-device-plugin /usr/bin/nvidia-device-plugin

CMD ["nvidia-device-plugin"]
