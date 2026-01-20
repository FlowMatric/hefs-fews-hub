# This Dockerfile aims to provide a Pangeo-style image with the VNC/Linux Desktop feature
# It was constructed by following the instructions and copying code snippets laid out
# and linked from here:
# https://github.com/2i2c-org/infrastructure/issues/1444#issuecomment-1187405324

FROM almalinux:8.10
# FROM 935462133478.dkr.ecr.us-east-2.amazonaws.com/teehr:v0.4-beta

USER root
# Install EPEL repository for additional packages
RUN --mount=type=cache,target=/var/cache/dnf \
    dnf install epel-release -y

# Install XFCE components individually to save space
RUN --mount=type=cache,target=/var/cache/dnf \
    dnf install -y \
    dbus-x11 \
    xfce4-session \
    xfce4-panel \
    xfce4-settings \
    xfdesktop \
    xfwm4 \
    xfce4-terminal \
    Thunar \
    xorg-x11-server-Xorg \
    xorg-x11-xinit \
    xorg-x11-xauth \
    xorg-x11-fonts-* \
    xorg-x11-utils \
    firefox \
    curl \
    wget \
    git-lfs \
    perl \
    unzip && \
    dnf clean all

# Install Node.js and npm
RUN curl -sL https://rpm.nodesource.com/setup_20.x | bash - \
    && dnf install -y nodejs

# Install TurboVNC (https://github.com/TurboVNC/turbovnc)
ARG TURBOVNC_VERSION=3.1
RUN wget -q "https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc-${TURBOVNC_VERSION}.x86_64.rpm/download" -O turbovnc.rpm \
    && dnf install -y turbovnc.rpm \
    && rm turbovnc.rpm \
    && ln -s /opt/TurboVNC/bin/* /usr/local/bin/

# Install Miniconda (for mamba/conda)
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}
RUN --mount=type=cache,target=/root/.conda/pkgs \
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p ${CONDA_DIR} \
    && rm /tmp/miniconda.sh \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
    && conda install -y mamba -c conda-forge \
    && mamba clean -afy

# Create conda environment and install packages
ENV CONDA_ENV=notebook
RUN --mount=type=cache,target=/root/.conda/pkgs \
    mamba create -n ${CONDA_ENV} -y python=3.11 \
    && mamba install -n ${CONDA_ENV} -y websockify ipywidgets-bokeh jupyterlab voila -c conda-forge

# Activate conda environment by default
ENV NB_PYTHON_PREFIX=${CONDA_DIR}/envs/${CONDA_ENV}
ENV PATH=${NB_PYTHON_PREFIX}/bin:${PATH}

# Install jupyter-remote-desktop-proxy with compatible npm version
RUN --mount=type=cache,target=/root/.cache/pip \
    npm install -g npm@7.24.0 \
    && pip install \
        https://github.com/jupyterhub/jupyter-remote-desktop-proxy/archive/main.zip

# Override the default xstartup script with one that works for XFCE on AlmaLinux
RUN echo '#!/bin/sh' > ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '# Ensure DISPLAY is set (should be passed by vncserver)' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'if [ -z "$DISPLAY" ]; then' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '    export DISPLAY=:1' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'fi' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'unset SESSION_MANAGER' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'unset DBUS_SESSION_BUS_ADDRESS' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '# Give X server a moment to initialize' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'sleep 1' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo '' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && echo 'exec /usr/bin/xfce4-session' >> ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup \
    && chmod +x ${NB_PYTHON_PREFIX}/lib/python3.11/site-packages/jupyter_remote_desktop_proxy/share/xstartup

# Install TEEHR
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir teehr

# Create jovyan user
ARG NB_USER=jovyan
ARG NB_UID=1000
ARG NB_GID=100
RUN groupadd -g ${NB_GID} ${NB_USER} || true \
    && useradd -m -s /bin/bash -u ${NB_UID} -g ${NB_GID} ${NB_USER} \
    && mkdir -p /home/${NB_USER}

# Copy in FEWS binaries from local directory
COPY fews/fews-NA-202102-115469-bin.zip /opt/fews/fews-NA-202102-115469-bin.zip
RUN unzip /opt/fews/fews-NA-202102-115469-bin.zip -d /opt/fews/ \
    && chown -R ${NB_USER}:${NB_GID} /opt/fews

# Panel dashboard setup
COPY playground/panel_dashboard.py playground/dashboard_funcs.py playground/start_dashboard.sh /opt/hefs_fews_dashboard/
COPY playground/geo/rfc_boundaries.geojson /opt/hefs_fews_dashboard/rfc_boundaries.geojson
COPY images/dashboard_icon2.png /opt/hefs_fews_dashboard/dashboard_icon2.png
COPY images/CIROHLogo_200x200.png /opt/hefs_fews_dashboard/CIROHLogo_200x200.png
COPY scripts/dashboard.desktop /opt/hefs_fews_dashboard/dashboard.desktop

RUN chown -R ${NB_USER}:${NB_GID} /opt/hefs_fews_dashboard \
    && chmod +x /opt/hefs_fews_dashboard/start_dashboard.sh \
    && chmod +x /opt/hefs_fews_dashboard/dashboard.desktop

# Install dashboard.desktop to XFCE applications menu
RUN mkdir -p /home/${NB_USER}/.local/share/applications \
    && cp /opt/hefs_fews_dashboard/dashboard.desktop /home/${NB_USER}/.local/share/applications/ \
    && mkdir -p /home/${NB_USER}/Desktop \
    && cp /opt/hefs_fews_dashboard/dashboard.desktop /home/${NB_USER}/Desktop/ \
    && chown -R ${NB_USER}:${NB_GID} /home/${NB_USER}/.local \
    && chown -R ${NB_USER}:${NB_GID} /home/${NB_USER}/Desktop

# Setup VNC for jovyan user (jupyter-remote-desktop-proxy will use this)
RUN mkdir -p /home/${NB_USER}/.vnc \
    && echo '#!/bin/bash' > /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && echo 'unset SESSION_MANAGER' >> /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && echo 'export XDG_SESSION_TYPE=x11' >> /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && echo 'export XDG_CURRENT_DESKTOP=XFCE' >> /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && echo 'dbus-launch --exit-with-session startxfce4 &' >> /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && chmod +x /home/${NB_USER}/.vnc/xstartup.turbovnc \
    && chown -R ${NB_USER}:${NB_GID} /home/${NB_USER}/.vnc

USER ${NB_USER}

WORKDIR /home/jovyan