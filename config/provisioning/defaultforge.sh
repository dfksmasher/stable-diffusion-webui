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
    #"https://huggingface.co/John6666/obsession-illustriousxl-v20-sdxl/resolve/main/unet/diffusion_pytorch_model.safetensors|illustriousxl-personal-merge-v30noob10based-sdxl.safetensors"
	#"https://huggingface.co/John6666/noobai-xl-nai-xl-vpredtestversion-sdxl/resolve/main/unet/diffusion_pytorch_model.safetensors|noobai-xl-nai-xl-vpredtestversion-sdxl.safetensors"
	#"https://huggingface.co/Laxhar/noob_sdxl_v_pred/resolve/main/vpred-model/Vpred-checkpoint-e0_s5000.safetensors")
https://huggingface.co/Laxhar/noobai-XL-Vpred-0.5/resolve/main/noobai-xl-vpred-v0.5.safetensors
# Other arrays (LORA_MODELS, VAE_MODELS, etc.)...

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

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
    git clone --branch dev_upstream https://github.com/Panchovix/stable-diffusion-webui-reForge.git /opt/stable-diffusion-webui

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

    # Install additional packages
    pip_install "${PIP_PACKAGES[@]}"

    # Add 'dat_enabled_models' to config.json
    CONFIG_FILE="/opt/stable-diffusion-webui/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
    fi
    # Update config.json using jq
    jq '.dat_enabled_models = []' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    provisioning_get_extensions
    provisioning_get_models \
        "/opt/stable-diffusion-webui/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"
    # ... Rest of your provisioning_get_models calls ...

    # ... Rest of your function ...
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    chmod a+w "$dir"
    shift
    if [[ $DISK_GB_ALLOCATED -ge $DISK_GB_REQUIRED ]]; then
        arr=("$@")
    else
        printf "WARNING: Low disk space allocation - Only the first model will be downloaded!\n"
        arr=("$1")
    fi

    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for entry in "${arr[@]}"; do
        if [[ "$entry" == *"|"* ]]; then
            IFS='|' read -r url filename <<< "$entry"
        else
            url="$entry"
            filename=""
        fi
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}" "${filename}" || echo "Failed to download ${url}"
        printf "\n"
    done
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local dotbytes="${4:-4M}"

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

# ... Rest of your functions ...

provisioning_start
