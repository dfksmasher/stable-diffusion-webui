#!/bin/bash
set -x
# This file will be sourced in init.sh
# Namespace functions with provisioning_

# Provisioning script for stable-diffusion-webui-reForge (dev_upstream branch)

### Edit the following arrays to suit your workflow - values must be quoted and separated by newlines or spaces.
### If you specify gated models, you'll need to set environment variables HF_TOKEN and/or CIVITAI_TOKEN

DISK_GB_REQUIRED=30

APT_PACKAGES=(
    "jq"
)

PIP_PACKAGES=(
    "peft"
    "insightface"
)

EXTENSIONS=(
    "https://github.com/DominikDoom/a1111-sd-webui-tagcomplete"
    "https://github.com/ArtVentureX/sd-webui-agent-scheduler"
    "https://github.com/dfksmasher/sd-webui-ar"
    "https://github.com/dfksmasher/sd-dynamic-prompts"
    "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"
)

CHECKPOINT_MODELS=(
   #"https://huggingface.co/John6666/noobai-xl-nai-xl-vpredtestversion-sdxl/resolve/main/unet/diffusion_pytorch_model.safetensors|noobai-xl-nai-xl-vpredtestversion-sdxl.safetensors"
    "https://huggingface.co/Laxhar/noobai-XL-Vpred-0.5/resolve/main/noobai-xl-vpred-v0.5.safetensors|noobai-xl-vpred-v0.5.safetensors"
)

function provisioning_start() {
    # Ensure Python 3.10 is installed and set as default
    sudo apt-get update
    sudo apt-get install -y python3.10 python3.10-venv python3.10-dev "${APT_PACKAGES[@]}"
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
    git clone --branch dev https://github.com/Panchovix/stable-diffusion-webui-reForge.git /opt/stable-diffusion-webui

    DISK_GB_AVAILABLE=$(($(df --output=avail -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_USED=$(($(df --output=used -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_ALLOCATED=$(($DISK_GB_AVAILABLE + $DISK_GB_USED))

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages

    # Install requirements for reForge
    cd /opt/stable-diffusion-webui || { echo "Failed to navigate to /opt/stable-diffusion-webui"; exit 1; }
    pip_install -r requirements.txt
    if [[ -f requirements_versions.txt ]]; then
        pip_install -r requirements_versions.txt
    fi

    # Install additional packages
    pip_install "${PIP_PACKAGES[@]}"

    # Add 'dat_enabled_models' to config.json
    CONFIG_FILE="/opt/stable-diffusion-webui/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
    fi
    jq '.dat_enabled_models = []' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    provisioning_get_extensions
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"
}

function provisioning_print_header() {
    echo "##########################################################"
    echo "# Starting Provisioning for stable-diffusion-webui      #"
    echo "##########################################################"
    echo "Disk Space Allocated: $DISK_GB_ALLOCATED GB, Required: $DISK_GB_REQUIRED GB"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        echo "WARNING: Disk space allocation is below the required threshold!"
    fi
}

function provisioning_get_apt_packages() {
    echo "Installing APT packages: ${APT_PACKAGES[*]}"
    sudo apt-get install -y "${APT_PACKAGES[@]}"
}

function provisioning_get_pip_packages() {
    echo "Installing Python packages: ${PIP_PACKAGES[*]}"
    pip_install "${PIP_PACKAGES[@]}"
}

function pip_install() {
    "$WEBUI_VENV_PIP" install --no-cache-dir "$@"
}

function provisioning_get_extensions() {
    echo "Installing Extensions..."
    for repo in "${EXTENSIONS[@]}"; do
        dir="${repo##*/}"
        path="/opt/stable-diffusion-webui/extensions/${dir}"
        if [[ -d $path ]]; then
            echo "Updating extension: ${repo}"
            (cd "$path" && git pull)
        else
            echo "Cloning extension: ${repo}"
            git clone "${repo}" "$path"
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then
        echo "No models specified for downloading."
        return 1
    fi
    dir="$1"
    mkdir -p "$dir"
    chmod a+w "$dir"
    shift
    if [[ $DISK_GB_ALLOCATED -ge $DISK_GB_REQUIRED ]]; then
        arr=("$@")
    else
        echo "WARNING: Low disk space allocation - Only the first model will be downloaded!"
        arr=("$1")
    fi

    echo "Downloading ${#arr[@]} model(s) to $dir..."
    for entry in "${arr[@]}"; do
        if [[ "$entry" == *"|"* ]]; then
            IFS='|' read -r url filename <<< "$entry"
        else
            url="$entry"
            filename=""
        fi
        echo "Downloading: ${url}"
        provisioning_download "${url}" "${dir}" "${filename}" || echo "Failed to download ${url}"
    done
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local dotbytes="${4:-4M}"

    mkdir -p "$dir" || { echo "Failed to create directory $dir"; return 1; }

    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $auth_token ]]; then
        if [[ -n "$filename" ]]; then
            wget --header="Authorization: Bearer $auth_token" --content-disposition --show-progress -e dotbytes="$dotbytes" -O "$dir/$filename" "$url" || echo "Failed to download $url"
        else
            wget --header="Authorization: Bearer $auth_token" --content-disposition --show-progress -e dotbytes="$dotbytes" -P "$dir" "$url" || echo "Failed to download $url"
        fi
    else
        if [[ -n "$filename" ]]; then
            wget --content-disposition --show-progress -e dotbytes="$dotbytes" -O "$dir/$filename" "$url" || echo "Failed to download $url"
        else
            wget --content-disposition --show-progress -e dotbytes="$dotbytes" -P "$dir" "$url" || echo "Failed to download $url"
        fi
    fi
}

provisioning_start
