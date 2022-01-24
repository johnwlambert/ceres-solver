#!/bin/bash

# The OS is centOS 7, instead of Ubuntu.

# Author: John Lambert (johnwlambert)

uname -a
echo "Current CentOS Version:"
cat /etc/centos-release

yum -y install wget

ls -ltrh /io/

# we cannot simply use `pip` or `python`, since points to old 2.7 version
PYBIN="/opt/python/$PYTHON_VERSION/bin"
PYVER_NUM=$($PYBIN/python -c "import sys;print(sys.version.split(\" \")[0])")
PYTHONVER="$(basename $(dirname $PYBIN))"

echo "Python bin path: $PYBIN"
echo "Python version number: $PYVER_NUM"
echo "Python version: $PYTHONVER"

export PATH=$PYBIN:$PATH

${PYBIN}/pip install auditwheel

PYTHON_EXECUTABLE=${PYBIN}/python
# We use distutils to get the include directory and the library path directly from the selected interpreter
# We provide these variables to CMake to hint what Python development files we wish to use in the build.
PYTHON_INCLUDE_DIR=$(${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON_LIBRARY=$(${PYTHON_EXECUTABLE} -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR'))")

CURRDIR=$(pwd)

echo "Num. processes to use for building: ${nproc}"

# ------ Install boost (build it staticly) ------
cd $CURRDIR
yum install -y wget libicu libicu-devel centos-release-scl-rh devtoolset-7-gcc-c++

# Download and install Boost-1.65.1
# colmap needs only program_options filesystem graph system unit_test_framework
mkdir -p boost && \
    cd boost && \
    wget -nv https://boostorg.jfrog.io/artifactory/main/release/1.65.1/source/boost_1_65_1.tar.gz && \
    tar xzf boost_1_65_1.tar.gz && \
    cd boost_1_65_1 && \
    ./bootstrap.sh --with-libraries=serialization,filesystem,thread,system,atomic,date_time,timer,chrono,program_options,regex,graph,test && \
    ./b2 -j$(nproc) cxxflags="-fPIC" runtime-link=static variant=release link=static install

# Boost should now be visible under /usr/local
ls -ltrh /usr/local

# ------ Install dependencies from the default Ubuntu repositories ------
cd $CURRDIR
yum install \
    git \
    cmake \
    build-essential \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libfreeimage-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libglew-dev \
    libcgal-dev


# Note: `yum install gflags` will not work, since the version is too old (2.1)
# Note: `yum install glog` will also not work, since the version is too old
# Cloning and building https://github.com/google/glog.git will also not work, due to linker issues.
yum -y install gflags-devel glog-devel

cd $CURRDIR
# Using Eigen 3.3, not Eigen 3.4
wget https://gitlab.com/libeigen/eigen/-/archive/3.3.9/eigen-3.3.9.tar.gz
tar -xvzf eigen-3.3.9.tar.gz
export EIGEN_DIR="$CURRDIR/eigen-3.3.9"

# While Eigen is a header-only library, it still has to be built!
# Creates Eigen3Config.cmake from Eigen3Config.cmake.in
cd $EIGEN_DIR
mkdir build
cd build
cmake ..

ls -ltrh "$EIGEN_DIR/cmake/"

# ------ Install CERES solver ------
cd $CURRDIR
yum install libeigen3-dev # was not in COLMAP instructions
yum install libatlas-base-dev libsuitesparse-dev
yum install libgoogle-glog-dev libgflags-dev # was not in COLMAP instructions

git clone https://ceres-solver.googlesource.com/ceres-solver
cd ceres-solver
git checkout $(git describe --tags) # Checkout the latest release
mkdir build
cd build
cmake .. -DBUILD_TESTING=OFF \
         -DBUILD_EXAMPLES=OFF \
         -DEigen3_DIR="$EIGEN_DIR/cmake/"
make -j$(nproc)
make install

