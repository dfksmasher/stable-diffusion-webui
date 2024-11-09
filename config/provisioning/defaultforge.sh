#!/bin/bash
# This file will be sourced in init.sh
# Namespace functions with provisioning_

# Provisioning script for stable-diffusion-webui-reForge (dev_upstream branch)

### Edit the following arrays to suit your workflow - values must be quoted and separated by newlines or spaces.
### If you specify gated models, you'll need to set environment variables HF_TOKEN and/or CIVITAI_TOKEN

DISK_GB_REQUIRED=30

APT_PACKAGES=(
    # Add any additional APT packages if needed
)

PIP_PACKAGES=(
    # Add any additional PIP packages if needed
)

EXTENSIONS=(
    "https://github.com/DominikDoom/a1111-sd-webui-tagcomplete"
    "https://github.com/ArtVentureX/sd-webui-agent-scheduler"
    "https://github.com/dfksmasher/sd-webui-ar"
    "https://github.com/dfksmasher/sd-dynamic-prompts"
    "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"
)

CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/1022833"
    "https://civitai.com/api/download/models/1023901"
    "https://civitai.com/api/download/models/962003"
)

LORA_MODELS=(
    # Add any LoRA models if needed
)

VAE_MODELS=(
    # Add any VAE models if needed
)

ESRGAN_MODELS=(
    # Add any ESRGAN models if needed
)

CONTROLNET_MODELS=(
    # Add any ControlNet models if needed
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    # Ensure Python 3.10 is installed and set as default
    sudo apt-get update
    sudo apt-get install -y python3.10 python3.10-venv python3.10-dev
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
    sudo update-alternatives --set python3 /usr/bin/python3.10

    # Apply workarounds if needed
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh webui

    # Remove existing repository if it exists
    rm -rf /opt/stable-diffusion-webui

    # Clone the reForge repository (dev_upstream branch)
    git clone --branch dev_upstream https://github.com/Panchovix/stable-diffusion-webui-reForge.git /opt/stable-diffusion-webui

    # Alternatively, you can use:
    # git clone https://github.com/Panchovix/stable-diffusion-webui-reForge.git /opt/stable-diffusion-webui
    # cd /opt/stable-diffusion-webui
    # git checkout dev_upstream

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
        "/opt/stable-diffusion-webui/models/Lora" \
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
    ARGS_COMBINED="${PLATFORM_ARGS} $(cat /etc/a1111_webui_flags.conf 2>/dev/null) ${PROVISIONING_ARGS}"

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

function provisioning_get_apt_packages() {
    if [[ -n "${APT_PACKAGES[*]}" ]]; then
        sudo apt-get install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n "${PIP_PACKAGES[*]}" ]]; then
        pip_install "${PIP_PACKAGES[@]}"
    fi
}

function provisioning_get_extensions() {
    for repo in "${EXTENSIONS[@]}"; do
        dir="${repo##*/}"
        path="/opt/stable-diffusion-webui/extensions/${dir}"
        if [[ -d $path ]]; then
            # Pull only if AUTO_UPDATE
            if [[ ${AUTO_UPDATE,,} == "true" ]]; then
                printf "Updating extension: %s...\n" "${repo}"
                ( cd "$path" && git pull )
            fi
        else
            printf "Downloading extension: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    if [[ $DISK_GB_ALLOCATED -ge $DISK_GB_REQUIRED ]]; then
        arr=("$@")
    else
        printf "WARNING: Low disk space allocation - Only the first model will be downloaded!\n"
        arr=("$1")
    fi

    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#                                            #\n"
    printf "#          Provisioning container            #\n"
    printf "#                                            #\n"
    printf "#         This will take some time           #\n"
    printf "#                                            #\n"
    printf "# Your container will be ready on completion #\n"
    printf "#                                            #\n"
    printf "##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Web UI will start now\n\n"
}

provisioning_start
