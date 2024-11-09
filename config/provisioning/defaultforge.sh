#!/bin/bash
# This file will be sourced in init.sh
# Namespace functions with provisioning_

# https://raw.githubusercontent.com/ai-dock/stable-diffusion-webui/main/config/provisioning/default.sh

### Edit the following arrays to suit your workflow - values must be quoted and separated by newlines or spaces.
### If you specify gated models you'll need to set environment variables HF_TOKEN and/or CIVITAI_TOKEN
EXTENSIONS=(
   "https://github.com/DominikDoom/a1111-sd-webui-tagcomplete"
   "https://github.com/ArtVentureX/sd-webui-agent-scheduler"
   "https://github.com/dfksmasher/sd-webui-ar"
   "https://github.com/dfksmasher/sd-dynamic-prompts"
   "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"  
)
# [Your arrays: DISK_GB_REQUIRED, APT_PACKAGES, PIP_PACKAGES, EXTENSIONS, CHECKPOINT_MODELS, etc.]

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    # Ensure Python 3.10 is installed and set as default
    sudo apt-get update
    sudo apt-get install -y python3.10 python3.10-venv python3.10-dev
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
    sudo update-alternatives --set python3 /usr/bin/python3.10

    # We need to apply some workarounds to make old builds work with the new default
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh webui

    # Remove existing repository if it exists
    rm -rf /opt/stable-diffusion-webui

    # Clone the reForge repository
    git clone https://github.com/Panchovix/stable-diffusion-webui-reForge.git /opt/stable-diffusion-webui

    DISK_GB_AVAILABLE=$(($(df --output=avail -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_USED=$(($(df --output=used -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_ALLOCATED=$(($DISK_GB_AVAILABLE + $DISK_GB_USED))
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages

    # Install requirements for reForge
    cd /opt/stable-diffusion-webui
    pip_install -r requirements.txt
    if [[ -f requirements_versions.txt ]]; then
        pip_install -r requirements_versions.txt
    fi

    provisioning_get_extensions
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/ControlNet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/VAE" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/ESRGAN" \
        "${ESRGAN_MODELS[@]}"

    PLATFORM_ARGS=""
    if [[ $XPU_TARGET = "CPU" ]]; then
        PLATFORM_ARGS="--use-cpu all --skip-torch-cuda-test --no-half"
    fi
    PROVISIONING_ARGS="--skip-python-version-check --no-download-sd-model --do-not-download-clip --port 11404 --exit"
    ARGS_COMBINED="${PLATFORM_ARGS} $(cat /etc/a1111_webui_flags.conf) ${PROVISIONING_ARGS}"

    # Start and exit because webui will probably require a restart
    cd /opt/stable-diffusion-webui
    if [[ -z $MAMBA_BASE ]]; then
        source "$WEBUI_VENV/bin/activate"
        LD_PRELOAD=libtcmalloc.so python webui.py \
            ${ARGS_COMBINED}
        deactivate
    else 
        micromamba run -n webui -e LD_PRELOAD=libtcmalloc.so python webui.py \
            ${ARGS_COMBINED}
    fi
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$WEBUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n webui pip install --no-cache-dir "$@"
    fi
}

# Add the missing functions here
# [Include provisioning_get_apt_packages, provisioning_get_extensions, provisioning_get_models, provisioning_download, and any other necessary functions]

provisioning_start
