#!/bin/bash

# script functions_disk.sh

# Fonction pour convertir les tailles en MiB
# convert_to_mib() {
#     local size="$1"
#     local numeric_size

#     # Si la taille est en GiB, on la convertit en MiB (1GiB = 1024MiB)
#     if [[ "$size" =~ ^[0-9]+GiB$ ]]; then
#         numeric_size=$(echo "$size" | sed 's/GiB//')
#         echo $(($numeric_size * 1024))  # Convertir en MiB
#     # Si la taille est en GiB avec "G", convertir aussi en MiB
#     elif [[ "$size" =~ ^[0-9]+G$ ]]; then
#         numeric_size=$(echo "$size" | sed 's/G//')
#         echo $(($numeric_size * 1024))  # Convertir en MiB
#     elif [[ "$size" =~ ^[0-9]+MiB$ ]]; then
#         # Si la taille est déjà en MiB, on la garde telle quelle
#         echo "$size" | sed 's/MiB//'
#     elif [[ "$size" =~ ^[0-9]+M$ ]]; then
#         # Si la taille est en Mo (en utilisant 'M'), convertir en MiB (1 Mo = 1 MiB dans ce contexte)
#         numeric_size=$(echo "$size" | sed 's/M//')
#         echo "$numeric_size"
#     elif [[ "$size" =~ ^[0-9]+%$ ]]; then
#         # Si la taille est un pourcentage, retourner "100%" directement
#         echo "$size"
#     else
#         echo "0"  # Retourne 0 si l'unité est mal définie
#     fi
# }

# Convertit les tailles en MiB
convert_to_mib() {
    local size="$1"
    case "$size" in
        *"GiB"|*"G") 
            echo "$size" | sed 's/[GiB|G]//' | awk '{print $1 * 1024}'
            ;;
        *"MiB"|*"M")
            echo "$size" | sed 's/[MiB|M]//'
            ;;
        *"%")
            echo "$size"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Détermine le type de disque
get_disk_prefix() {
    [[ "$1" == nvme* ]] && echo "p" || echo ""
}

# detect_disk_type() {
#     local disk="$1"
#     case "$disk" in
#         nvme*)
#             echo "nvme"
#             ;;
#         sd*)
#             # Test supplémentaire pour distinguer SSD/HDD
#             local rotational=$(cat "/sys/block/$disk/queue/rotational" 2>/dev/null)
#             if [[ "$rotational" == "0" ]]; then
#                 echo "ssd"
#             else
#                 echo "hdd"
#             fi
#             ;;
#         *)
#             echo "basic"
#             ;;
#     esac
# }

# Fonction pour formater l'affichage de la taille d'une partition en GiB ou MiB
format_space() {
    local space=$1
    local space_in_gib

    # Si la taille est supérieur ou égal à 1 Go (1024 MiB), afficher en GiB
    if (( space >= 1024 )); then
        # Convertion en GiB
        space_in_gib=$(echo "scale=2; $space / 1024" | bc)
        echo "${space_in_gib} GiB"
    else
        # Si la taille est inférieur à 1 GiB, afficher en MiB
        echo "${space} MiB"
    fi
}

# Fonction pour afficher les informations des partitions
show_disk_partitions() {
    
    local status="$1"
    local disk="$2"
    local partitions
    local NAME
    local SIZE
    local FSTYPE
    local LABEL
    local MOUNTPOINT
    local UUID


    log_prompt "INFO" && echo "$status" && echo ""
    echo "Device : /dev/$disk"
    echo "Taille : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
    echo "Type : $(lsblk -n -o TRAN "/dev/$disk")"
    echo -e "\nInformations des partitions :"
    echo "----------------------------------------"
    # En-tête
    printf "%-10s %-10s %-10s %-15s %-15s %s\n" \
        "PARTITION" "TAILLE" "TYPE FS" "LABEL" "POINT MONT." "UUID"
    echo "----------------------------------------"

    while IFS= read -r partition; do
        partitions+=("$partition")
    done < <(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | sed -n "s/^[[:graph:]]*${disk}\([0-9]*\)$/${disk}\1/p")

    # Affiche les informations de chaque partition
    for partition in "${partitions[@]}"; do  # itérer sur le tableau des partitions
        if [ -b "/dev/$partition" ]; then
            # Récupérer chaque colonne séparément pour éviter toute confusion
            NAME=$(lsblk "/dev/$partition" -n -o NAME)
            SIZE=$(lsblk "/dev/$partition" -n -o SIZE)
            FSTYPE=$(lsblk "/dev/$partition" -n -o FSTYPE)
            LABEL=$(lsblk "/dev/$partition" -n -o LABEL)
            MOUNTPOINT=$(lsblk "/dev/$partition" -n -o MOUNTPOINT)
            UUID=$(lsblk "/dev/$partition" -n -o UUID)

            # Gestion des valeurs vides
            NAME=${NAME:-"[vide]"}
            SIZE=${SIZE:-"[vide]"}
            FSTYPE=${FSTYPE:-"[vide]"}
            LABEL=${LABEL:-"[vide]"}
            MOUNTPOINT=${MOUNTPOINT:-"[vide]"}
            UUID=${UUID:-"[vide]"}


            # Affichage formaté
            printf "%-10s %-10s %-10s %-15s %-15s %s\n" "$NAME" "$SIZE" "$FSTYPE" "$LABEL" "$MOUNTPOINT" "$UUID"
            
        fi
    done

    # Résumé
    echo -e "\nRésumé :"
    echo "Nombre de partitions : $(echo "${partitions[@]}" | wc -w)"  
    echo "Espace total : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"

}


# Fonction pour effacer tout le disque
erase_disk() {
    local disk="$1"
    local disk_size
    local mounted_parts
    local swap_parts
    
    # Récupérer les partitions montées (non-swap)
    mounted_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep -v "\[SWAP\]" | grep -v "^$disk " | grep -v " $")
    # Liste des partitions swap
    swap_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep "\[SWAP\]")
    
    # Gérer les partitions montées (non-swap)
    if [ -n "$mounted_parts" ]; then
        log_prompt "INFO" && echo "ATTENTION: Certaines partitions sont montées :" && echo
        echo "$mounted_parts"
        echo ""
        log_prompt "INFO" && read -p "Voulez-vous les démonter ? (y/n) : " response && echo

        if [[ "$response" =~ ^[yY]$ ]]; then
            while read -r part mountpoint; do
                log_prompt "INFO" && echo "Démontage de /dev/$part" && echo ""
                umount "/dev/$part" 
                if [ $? -ne 0 ]; then
                    log_prompt "ERROR" && echo "Démontage de /dev/$part impossible" && echo
                fi
            done <<< "$mounted_parts"
        else
            log_prompt "WARNING" && echo "Opération annulée" && echo
            return 1
        fi
    fi
    
    # Gérer les partitions swap séparément
    if [ -n "$swap_parts" ]; then
        log_prompt "INFO" && echo "ATTENTION: Certaines partitions swap sont activées :" && echo
        echo "$swap_parts"
        echo
        log_prompt "INFO" && read -p "Voulez-vous les démonter ? (y/n) : " response && echo

        if [[ "$response" =~ ^[yY]$ ]]; then
            while read -r part _; do
                log_prompt "INFO" && echo "Démontage de /dev/$part" && echo
                swapoff "/dev/$part"
                if [ $? -ne 0 ]; then
                    log_prompt "ERROR" && echo "Démontage de /dev/$part impossible" && echo
                fi
            done <<< "$swap_parts"
        else
            log_prompt "WARNING" && echo "Opération annulée" && echo
            return 1
        fi
    fi
    
    echo "ATTENTION: Vous êtes sur le point d'effacer TOUT le disque /dev/$disk"
    echo "Cette opération est IRRÉVERSIBLE !"
    echo "Toutes les données seront DÉFINITIVEMENT PERDUES !"
    echo 
    log_prompt "INFO" && read -p "Êtes-vous vraiment sûr ? (y/n) : " response && echo

    if [[ "$response" =~ ^[yY]$ ]]; then
        log_prompt "INFO" && echo "Effacement du disque /dev/$disk en cours ..." && echo

        # Obtenir la taille exacte du disque en blocs
        disk_size=$(blockdev --getsz "/dev/$disk")
        # Utilisation de dd avec la taille exacte du disque
        dd if=/dev/zero of="/dev/$disk" bs=512 count=$disk_size status=progress
        sync
    else
        log_prompt "WARNING" && echo "Opération annulée" && echo
        return 1
    fi
}

# Crée et formate les partitions
preparation_disk() {
    local disk="$1"
    local partition_prefix=$(get_disk_prefix "$disk")
    local start="1MiB"
    local partition_num=1

    # Afficher le résumé
    log_prompt "INFO" && echo "Création des partitions sur /dev/$disk :" && echo
    printf "%-10s %-10s %-10s\n" "Partition" "Taille" "Type"
    echo "--------------------------------"
    for part in "${PARTITIONS_CREATE[@]}"; do
        IFS=':' read -r name size type <<< "$part"
        printf "%-10s %-10s %-10s\n" "$name" "$size" "$type"
    done
    echo
    read -rp "Continuer ? (y/n): " confirm
    [[ "$confirm" != [yY] ]] && exit 1

    # Créer la table de partitions GPT
    parted --script /dev/$disk mklabel gpt

    # Créer chaque partition
    for part in "${PARTITIONS_CREATE[@]}"; do
        IFS=':' read -r name size type <<< "$part"
        local device="/dev/${disk}${partition_prefix}${partition_num}"
        local end=$([ "$size" = "100%" ] && echo "100%" || echo "$(convert_to_mib "$size")MiB")

        # Créer la partition
        parted --script -a optimal /dev/$disk mkpart primary "$start" "$end"

        # Configurer les flags et formater
        case "$name" in
            "boot")
                parted --script /dev/$disk set "$partition_num" esp on
                mkfs.vfat -F32 -n "$name" "$device"
                ;;
            "swap")
                parted --script /dev/$disk set "$partition_num" swap on
                mkswap -L "$name" "$device" && swapon "$device"
                ;;
            "root")
                mkfs.btrfs -f -L "$name" "$device"
                ;;
        esac

        start="$end"
        ((partition_num++))
    done

    echo "Partitionnement terminé avec succès"
}

mount_partitions() {
    local disk="$1"
    
    # Récupérer toutes les partitions du disque
    local partitions=($(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | sed -n "s/^[[:graph:]]*${disk}\([0-9]*\)$/${disk}\1/p"))
    
    # Identifier les partitions par leur label
    local root_part="" boot_part="" home_part=""

    for part in "${partitions[@]}"; do
        local label=$(lsblk "/dev/$part" -n -o LABEL)
        case "$label" in
            "root") root_part=$part ;;
            "boot") boot_part=$part ;;
            "swap") continue ;;
            *) echo "Partition ignorée: /dev/$part (Label: $label)" ;;
        esac
    done

    # Monter et configurer la partition root avec BTRFS
    if [[ -n "$root_part" ]]; then
        echo "Configuration de la partition root (/dev/$root_part)..."
        
        # Montage initial pour création des sous-volumes
        mount "/dev/$root_part" "${MOUNT_POINT}"
        
        # Créer les sous-volumes BTRFS
        for subvol in "${BTRFS_SUBVOLUMES[@]}"; do
            btrfs subvolume create "${MOUNT_POINT}/${subvol}"
        done
        
        # Démonter pour remonter avec les sous-volumes
        umount "${MOUNT_POINT}"
        
        # Monter le sous-volume principal
        mount -o "${BTRFS_MOUNT_OPTIONS},subvol=@" "/dev/$root_part" "${MOUNT_POINT}"
        
        # Créer et monter les points de montage pour chaque sous-volume
        declare -A mount_points=(
            ["@root"]="/root"
            ["@home"]="/home"
            ["@srv"]="/srv"
            ["@log"]="/var/log"
            ["@cache"]="/var/cache"
            ["@tmp"]="/tmp"
            ["@snapshots"]="/snapshots"
        )
        
        for subvol in "${!mount_points[@]}"; do
            local mount_point="${MOUNT_POINT}${mount_points[$subvol]}"
            mkdir -p "$mount_point"
            mount -o "${BTRFS_MOUNT_OPTIONS},subvol=${subvol}" "/dev/$root_part" "$mount_point"
        done
    fi

    # Monter la partition boot
    if [[ -n "$boot_part" ]]; then
        echo "Montage de la partition boot (/dev/$boot_part)..."
        mkdir -p "${MOUNT_POINT}/boot"
        mount "/dev/$boot_part" "${MOUNT_POINT}/boot"
    fi
}

# mount_partitions() {
    
#     local disk="$1"
#     local partitions=()
#     local root_partition=""
#     local boot_partition=""
#     local home_partition=""
#     local other_partitions=()

#     # Récupération des partitions du disque
#     while IFS= read -r partition; do
#         partitions+=("$partition")
#     done < <(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | sed -n "s/^[[:graph:]]*${disk}\([0-9]*\)$/${disk}\1/p")

#     # Trier et organiser les partitions
#     for part in "${partitions[@]}"; do
#         local part_label=$(lsblk "/dev/$part" -n -o LABEL)
#         case "$part_label" in
#             "root") 
#                 root_partition="$part"
#                 ;;
#             "boot") 
#                 boot_partition="$part"
#                 ;;
#             "home")
#                 home_partition="$part"
#                 ;;
#             *)
#                 other_partitions+=("$part")
#                 ;;
#         esac
#     done

#     # Monter la partition root EN PREMIER
#     if [[ -n "$root_partition" ]]; then
#         local NAME=$(lsblk "/dev/$root_partition" -n -o NAME)
#         local FSTYPE=$(lsblk "/dev/$root_partition" -n -o FSTYPE)
#         local LABEL=$(lsblk "/dev/$root_partition" -n -o LABEL)
#         local SIZE=$(lsblk "/dev/$root_partition" -n -o SIZE)

#         log_prompt "INFO" && echo "Traitement de la partition : /dev/$NAME (Label: $LABEL, FS: $FSTYPE)"

#         # Logique de montage de la partition root (identique à votre script original)
           
#         mount "/dev/$NAME" "${MOUNT_POINT}"

#         # Créer les sous-volumes de base
#         btrfs subvolume create "${MOUNT_POINT}/@"
#         btrfs subvolume create "${MOUNT_POINT}/@root"
#         btrfs subvolume create "${MOUNT_POINT}/@home"
#         btrfs subvolume create "${MOUNT_POINT}/@srv"
#         btrfs subvolume create "${MOUNT_POINT}/@log"
#         btrfs subvolume create "${MOUNT_POINT}/@cache"
#         btrfs subvolume create "${MOUNT_POINT}/@tmp"
#         btrfs subvolume create "${MOUNT_POINT}/@snapshots"
            
#         # Démonter la partition temporaire
#         umount "${MOUNT_POINT}"

#         # Remonter les sous-volumes avec des options spécifiques
#         echo "Montage des sous-volumes Btrfs avec options optimisées..."
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@ "/dev/$NAME" "${MOUNT_POINT}"

#         # Créer les sous-répertoires
#         mkdir -p "${MOUNT_POINT}/root"
#         mkdir -p "${MOUNT_POINT}/home"
#         mkdir -p "${MOUNT_POINT}/srv"
#         mkdir -p "${MOUNT_POINT}/var/log"
#         mkdir -p "${MOUNT_POINT}/var/cache/"
#         mkdir -p "${MOUNT_POINT}/tmp"
#         mkdir -p "${MOUNT_POINT}/snapshots"

#         # Montage des sous-volumes
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@root "/dev/$NAME" "${MOUNT_POINT}/root"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@home "/dev/$NAME" "${MOUNT_POINT}/home"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@tmp "/dev/$NAME" "${MOUNT_POINT}/tmp"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@srv "/dev/$NAME" "${MOUNT_POINT}/srv"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@log "/dev/$NAME" "${MOUNT_POINT}/var/log"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@cache "/dev/$NAME" "${MOUNT_POINT}/var/cache"
#         mount -o defaults,noatime,compress=zstd,commit=120,subvol=@snapshots "/dev/$NAME" "${MOUNT_POINT}/snapshots"
#     fi

#     # Monter la partition boot 
#     if [[ -n "$boot_partition" ]]; then
#         local NAME=$(lsblk "/dev/$boot_partition" -n -o NAME)
#         mkdir -p "${MOUNT_POINT}/boot"
#         mount "/dev/$NAME" "${MOUNT_POINT}/boot"
#     fi

#     # Monter la partition home 
#     if [[ -n "$home_partition" ]]; then
#         local NAME=$(lsblk "/dev/$home_partition" -n -o NAME)
#         mkdir -p "${MOUNT_POINT}/home"  
#         mount "/dev/$NAME" "${MOUNT_POINT}/home"
#     fi

#     # Monter les autres partitions
#     for partition in "${other_partitions[@]}"; do
#         local part_label=$(lsblk "/dev/$partition" -n -o LABEL)
        
#         # Ignorer la partition swap
#         if [[ "$part_label" == "swap" ]]; then
#             log_prompt "INFO" && echo "Partition swap déjà monté"
#             continue
#         fi

#         # Ajouter ici toute logique supplémentaire pour d'autres partitions étiquetées différemment
#         log_prompt "WARNING" && echo "Partition non traitée : /dev/$partition (Label: $part_label)"
#     done
# }