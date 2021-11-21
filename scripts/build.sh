set -e
# Tensorflow.

# Prepare TensorRT

##pip install /opt/TensorRT-8.0.0.3/python/tensorrt-8.0.0.3-cp39-none-linux_x86_64.whl
#pip install /opt/TensorRT-8.0.0.3/python/tensorrt-8.0.0.3-cp38-none-linux_x86_64.whl

CUR_DIR=$(pwd)

cd ${CUR_DIR}/tensorflow

export USE_DEFAULT_PYTHON_LIB_PATH=1
export TF_NEED_JEMALLOC=1
export TF_NEED_KAFKA=1
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_AWS=1
export TF_NEED_GCP=1
export TF_NEED_HDFS=1
export TF_NEED_S3=1
export TF_ENABLE_XLA=1
export TF_NEED_GDR=0
export TF_NEED_VERBS=0
export TF_NEED_OPENCL=1
export TF_NEED_MPI=0
export TF_NEED_TENSORRT=0
export TF_NEED_NGRAPH=0
export TF_NEED_IGNITE=0
export TF_NEED_ROCM=0
# From arch package:
#export TF_SYSTEM_LIBS="boringssl,curl,cython,gif,icu,libjpeg_turbo,lmdb,nasm,pcre,png,pybind11,zlib
export TF_SET_ANDROID_WORKSPACE=0
export TF_DOWNLOAD_CLANG=0
export GCC_HOST_COMPILER_PATH=/usr/bin/gcc-10
export HOST_C_COMPILER=/usr/bin/gcc-10
export HOST_CXX_COMPILER=/usr/bin/g++-10
export TF_CUDA_CLANG=0
export TF_CUDA_PATHS=${CUDA_DIR},${CONDA_PREFIX},/usr/lib,/usr
export TF_CUDA_VERSION=$(${CUDA_DIR}/bin/nvcc --version | sed -n 's/^.*release \(.*\),.*/\1/p')
export TF_CUDNN_VERSION=$(sed -n 's/^#define CUDNN_MAJOR\s*\(.*\).*/\1/p' ${CUDNN_DIR}/include/cudnn_version.h)

# against GTX 980M, GTX 1080
export TF_CUDA_COMPUTE_CAPABILITIES=sm_52,sm_61

export CC=gcc-10
export CXX=g++-10

tensorflow_version="2.7.0"
tensorflow_wheel="tensorflow-${tensorflow_version}-cp38-cp38-linux_${wheel_arch_suffix}.whl"
tensorflow_c_pkg="libtensorflow.tar.gz"
tensorflow_lite_pkg="libtensorflowlite.tar.gz"

# Target product directory
product_directory=build_tf${tensorflow_version}_py38_np1.19

TARGET_DIR=${CUR_DIR}/tensorflow_products/${product_directory}

if [ ! -e ${TARGET_DIR} ]; then
mkdir -p ${TARGET_DIR}
fi;

function check_and_configure() {
# For now, be sure to use gcc-10 and g++-10! for configure
if [ ! -e .tf_configure.bazelrc ]; then
## Maybe not? Currently we don't build with tensorrt support as it depends on cuda 10 and we're using cuda 11.
    python configure.py
fi;
}

function prep_build_directories() {
scratch_dir=${SCRATCH_DIR}/tensorflow_build
if [ ! -e ${scratch_dir} ]; then
    mkdir -p ${scratch_dir}/temp
fi;
export TMP=${scratch_dir}/temp
bazel_build_dir=${scratch_dir}/.bazel_dir
}

function build_bazel_target() {
# Build all needed components
bazel --output_user_root=${bazel_build_dir} \
    build --config=opt --verbose_failures --sandbox_debug --action_env=PATH --action_env=LD_LIBRARY_PATH \
        $1
        #//tensorflow/tools/lib_package:libtensorflow \
        //tensorflow/tools/pip_package:build_pip_package
}

## clean (May be needed if changing options or example)
#bazel --output_user_root=${bazel_build_dir} \
#    clean

## Build all needed components
#bazel --output_user_root=${bazel_build_dir} \
#    build --config=opt --verbose_failures --sandbox_debug --action_env=PATH --action_env=LD_LIBRARY_PATH \
#        #//tensorflow/tools/lib_package:libtensorflow \
#        //tensorflow/tools/pip_package:build_pip_package

####### -----Build tensorflow wheel------ ########
if [ ! -e ${TARGET_DIR}/${tensorflow_wheel} ]; then

# Prep build system 
check_and_configure
prep_build_directories

# Build with bazel
if [ ! -e ./bazel-bin/tensorflow/tools/pip_package/build_pip_package ];then
build_bazel_target //tensorflow/tools/pip_package:build_pip_package
fi;

# Build package
if [ ! -e /tmp/tensorflow_pkg/${tensorflow_wheel} ]; then
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
fi;

# Copy result to target directory
cp /tmp/tensorflow_pkg/${tensorflow_wheel} ${TARGET_DIR}

fi;

####### -----Build tensorflow c library ------ ########
if [ ! -e ${TARGET_DIR}/${tensorflow_c_pkg} ]; then

# Prep build system 
check_and_configure
prep_build_directories

# Build with bazel
if [ ! -e ./bazel-bin/tensorflow/tools/lib_package/${tensorflow_c_pkg} ]; then
build_bazel_target //tensorflow/tools/lib_package:libtensorflow
fi;

# Copy library
cp ./bazel-bin/tensorflow/tools/lib_package/${tensorflow_c_pkg} ${TARGET_DIR}

fi;

####### -----Build tensorflow lite library ------ ########

if [ ! -e ${TARGET_DIR}/${tensorflow_lite_pkg} ]; then

# Build Tensorflow lite
if [ ! -e tflite_build ]; then
mkdir tflite_build
fi;

# Build static library
if [ ! -e tflite_build/libtensorflow-lite.a ]; then

cd tflite_build

cmake ../tensorflow/lite -DTFLITE_ENABLE_GPU=ON
cmake --build . -j16

cd ..

fi;

if [ ! -e tflite_c_build ]; then
mkdir tflite_c_build
fi;

if [ ! -e tflite_c_build/libtensorflowlite_c.so ]; then

cd tflite_c_build

cmake ../tensorflow/lite/c -DTFLITE_ENABLE_GPU=ON
cmake --build . -j16

cd ..

fi;

if [ ! -e libtensorflowlite ]; then
mkdir -p libtensorflowlite
mkdir -p libtensorflowlite/include
mkdir -p libtensorflowlite/include/tensorflow/lite/c
mkdir -p libtensorflowlite/lib
fi;

cp tflite_c_build/libtensorflowlite_c.so libtensorflowlite/lib
cp tflite_build/libtensorflow-lite.a libtensorflowlite/lib
cp tensorflow/lite/c/*.h libtensorflowlite/include/tensorflow/lite/c

cd libtensorflowlite
tar -zcvf ${TARGET_DIR}/${tensorflow_lite_pkg} include lib

cd ..
rm -r libtensorflowlite

fi;
