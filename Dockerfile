FROM nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04
LABEL authors="HumanAIGC-Engineering"

ARG CONFIG_FILE=config/chat_with_minicpm.yaml

ENV DEBIAN_FRONTEND=noninteractive

# Use Tsinghua University APT mirrors
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# Update package list and install required dependencies
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.11 python3.11-dev python3.11-venv python3.11-distutils python3-pip git libgl1 libglib2.0-0

# Install ffmpeg
RUN apt-get install -y ffmpeg

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    python3.11 -m ensurepip --upgrade && \
    python3.11 -m pip install --upgrade pip

ARG WORK_DIR=/root/open-avatar-chat
WORKDIR $WORK_DIR

# Install core dependencies
COPY ./install.py $WORK_DIR/install.py
COPY ./pyproject.toml $WORK_DIR/pyproject.toml
COPY ./src/third_party $WORK_DIR/src/third_party

ENV UV_PYTHON_DISTRIBUTION_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/github-release/indygreg/python-build-standalone/releases/download/

ENV UV_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
ENV UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
RUN pip install uv --index-url https://pypi.tuna.tsinghua.edu.cn/simple 

RUN uv venv --python 3.11.11 --index-url https://pypi.tuna.tsinghua.edu.cn/simple 
RUN uv sync --no-install-workspace --index-url https://pypi.tuna.tsinghua.edu.cn/simple

ADD ./src $WORK_DIR/src

# Copy script files (must be copied before installing config dependencies)
ADD ./scripts $WORK_DIR/scripts

# Execute pre-config installation script
RUN echo "Using config file: ${CONFIG_FILE}"
COPY $CONFIG_FILE /tmp/build_config.yaml
RUN chmod +x $WORK_DIR/scripts/pre_config_install.sh && \
    $WORK_DIR/scripts/pre_config_install.sh --config /tmp/build_config.yaml

# Install config dependencies
RUN uv run install.py \
    --config /tmp/build_config.yaml \
    --uv \
    --skip-core 

# Execute post-config installation script
RUN chmod +x $WORK_DIR/scripts/post_config_install.sh && \
    $WORK_DIR/scripts/post_config_install.sh --config /tmp/build_config.yaml && \
    rm /tmp/build_config.yaml

ADD ./resource $WORK_DIR/resource
ADD ./.env* $WORK_DIR/

WORKDIR $WORK_DIR
ENTRYPOINT ["uv", "run", "src/demo.py"]
