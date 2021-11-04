source ~/conda3/bin/activate
CONDA_PREFIX=$(readlink -f ./venv)
conda activate ${CONDA_PREFIX}

export CUDA_DIR="/opt/cuda"
# For CuDNN
export CUDNN_DIR="/usr"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CONDA_PREFIX}/lib64

export SCRATCH_DIR=$(pwd)

# For CUPTI/TensorRT
#export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/cuda/extras/CUPTI/lib64:/opt/TensorRT-8.0.0.3/lib:/opt/cuda/lib64
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CUDA_DIR}/extras/CUPTI/lib64:${CUDA_DIR}/lib64

export CC_OPT_FLAGS="-march=broadwell -O3"
export wheel_arch_suffix="x86_64"
