#!/bin/bash



if [ $1 = build ]
then
    # matlab: 2017b, cuda8, disable cudnn
    export $PATH=/usr/local/cuda-8.0/bin:$PATH
    export $LD_LIBRARY_PATH=/usr/local/cudnn_v5/lib64:/usr/local/cuda-8.0/lib64:$LD_LIBRARY_PATH
    matlab -nodisplay -r "setup(true,struct('enableGpu',true, 'cudaRoot', '/usr/local/cuda-8.0', 'cudaMethod', 'nvcc', 'enableCudnn', false,'cudnnRoot', '/usr/local/cudnn_v5'));exit;"

elif [ $1 = run ]
then

    export $PATH=/usr/local/cuda-8.0/bin:$PATH
    export $LD_LIBRARY_PATH=/usr/local/cudnn_v5/lib64:/usr/local/cuda-8.0/lib64:$LD_LIBRARY_PATH
    export $CUDA_VISIBLE_DEVICES='1'
    matlab

fi
