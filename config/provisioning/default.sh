#!/bin/bash
# This file will be sourced in init.sh
# Namespace functions with provisioning_

# https://raw.githubusercontent.com/ai-dock/stable-diffusion-webui/main/config/provisioning/default.sh

### Edit the following arrays to suit your workflow - values must be quoted and separated by newlines or spaces.
### If you specify gated models you'll need to set environment variables HF_TOKEN and/orf CIVITAI_TOKEN

DISK_GB_REQUIRED=30

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

EXTENSIONS=(
   "https://github.com/Mikubill/sd-webui-controlnet"
   "https://github.com/DominikDoom/a1111-sd-webui-tagcomplete"
   "https://github.com/pkuliyi2015/multidiffusion-upscaler-for-automatic1111"
   "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"
   "https://github.com/ArtVentureX/sd-webui-agent-scheduler"
   "https://github.com/Coyote-A/ultimate-upscale-for-automatic1111"
   "https://github.com/dfksmasher/sd-webui-ar"
   "https://github.com/dfksmasher/sd-dynamic-prompts"
   "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"  
)

CHECKPOINT_MODELS=(
    #"https://huggingface.co/gangfuckkkkk/Startup/resolve/main/autismmixSDXL_autismmixConfetti.safetensors"
    #"https://huggingface.co/gangfuckkkkk/Startup/resolve/main/hassakuXLHentai_v13.safetensors"
    "https://huggingface.co/John6666/obsession-illustriousxl-v20-sdxl/resolve/main/unet/diffusion_pytorch_model.safetensors"
)

LORA_MODELS=(
    #"https://civitai.com/api/download/models/16576"
)

VAE_MODELS=(
    #"https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors"
    #"https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
    "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
    "https://huggingface.co/Akumetsu971/SD_Anime_Futuristic_Armor/resolve/main/4x_NMKD-Siax_200k.pth"
)

CONTROLNET_MODELS=(
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_canny.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_depth_V2.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_dw_openpose.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_lineart_anime_denoise.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_mlsd_V2.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_normal.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_normal_dsine.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_recolor_luminance.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_segment_animeface_V2.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_sketch.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_softedge.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_t2i-adapter_color_shuffle.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_tile_anime_alpha.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_tile_anime_beta.safetensors"
"https://huggingface.co/bdsqlsz/qinglong_controlnet-lllite/blob/main/bdsqlsz_controlllite_xl_tile_realistic.safetensors"
)


### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    # We need to apply some workarounds to make old builds work with the new default
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh webui

    DISK_GB_AVAILABLE=$(($(df --output=avail -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_USED=$(($(df --output=used -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_ALLOCATED=$(($DISK_GB_AVAILABLE + $DISK_GB_USED))
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages
    provisioning_get_extensions
    provisioning_get_models \
        "${WORKSPACE}/stable-diffusion-webui/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/stable-diffusion-webui/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/stable-diffusion-webui/models/ControlNet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/stable-diffusion-webui/models/VAE" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/stable-diffusion-webui/models/esrgan" \
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
        LD_PRELOAD=libtcmalloc.so python launch.py \
            ${ARGS_COMBINED}
        deactivate
    else 
        micromamba run -n webui -e LD_PRELOAD=libtcmalloc.so python launch.py \
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
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
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

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}


# Download from $1 URL to $2 file path
function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif 
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

provisioning_start
