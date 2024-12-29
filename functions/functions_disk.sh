#!/bin/bash

# script functions_disk.sh

# Fonction pour convertir les tailles en MiB
convert_to_mib() {
    local size="$1"
    local numeric_size

    # Si la taille est en GiB, on la convertit en MiB (1GiB = 1024MiB)
    if [[ "$size" =~ ^[0-9]+GiB$ ]]; then
        numeric_size=$(echo "$size" | sed 's/GiB//')
        echo $(($numeric_size * 1024))  # Convertir en MiB
    # Si la taille est en GiB avec "G", convertir aussi en MiB
    elif [[ "$size" =~ ^[0-9]+G$ ]]; then
        numeric_size=$(echo "$size" | sed 's/G//')
        echo $(($numeric_size * 1024))  # Convertir en MiB
    elif [[ "$size" =~ ^[0-9]+MiB$ ]]; then
        # Si la taille est déjà en MiB, on la garde telle quelle
        echo "$size" | sed 's/MiB//'
    elif [[ "$size" =~ ^[0-9]+M$ ]]; then
        # Si la taille est en Mo (en utilisant 'M'), convertir en MiB (1 Mo = 1 MiB dans ce contexte)
        numeric_size=$(echo "$size" | sed 's/M//')
        echo "$numeric_size"
    elif [[ "$size" =~ ^[0-9]+%$ ]]; then
        # Si la taille est un pourcentage, retourner "100%" directement
        echo "$size"
    else
        echo "0"  # Retourne 0 si l'unité est mal définie
    fi
}

detect_disk_type() {
    local disk="$1"
    case "$disk" in
        nvme*)
            echo "nvme"
            ;;
        sd*)
            # Test supplémentaire pour distinguer SSD/HDD
            local rotational=$(cat "/sys/block/$disk/queue/rotational" 2>/dev/null)
            if [[ "$rotational" == "0" ]]; then
                echo "ssd"
            else
                echo "hdd"
            fi
            ;;
        *)
            echo "basic"
            ;;
    esac
}

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

preparation_disk() {
    local disk="$1"
    local disk_type=$(detect_disk_type "$disk")
    local partition_number=1
    local start="1MiB"

    # Affichage des informations de configuration
    echo "Configuration actuelle :"
    echo "----------------------------"
    echo "Zone : $ZONE"
    echo "Pays : $PAYS"
    echo "Ville : $CITY"
    echo "Langue : $LANG"
    echo "Locale : $LOCALE"
    echo "Disposition du clavier : $KEYMAP"
    echo "Nom d'hôte : $HOSTNAME"
    echo "Port SSH : $SSH_PORT"
    echo
    echo "Point de montage principal : $MOUNT_POINT"
    echo "Mode de démarrage détecté : $MODE"
    echo "Chargeur de démarrage utilisé : $BOOTLOADER"
    echo

    echo "Partitions à créer :"
    echo "----------------------------"
    for partition in "${PARTITIONS_CREATE[@]}"; do
        IFS=":" read -r name size fstype <<< "$partition"
        echo "==> Partition : $name - Taille : $size - Type : $fstype"
    done

    echo "----------------------------"
    echo
    echo "Veuillez vérifier les informations ci-dessus avant de continuer."
    log_prompt "INFO" && echo "Vous pouvez modifier le fichier config.sh pour adapter la configuration selon vos besoins."
    echo
    # Demander confirmation à l'utilisateur pour procéder à la création des partitions
    log_prompt "INFO" && read -rp "Souhaitez-vous continuer avec cette configuration ? (y/n) : " user_input

    if [[ "$user_input" != "y" && "$user_input" != "Y" ]]; then
        echo "Annulation du processus. Aucune partition n'a été créée."
        exit 1
    fi

    # Si l'utilisateur accepte, procéder à la création des partitions
    echo "Procédure de création des partitions en cours..."

    # Création de la table de partitions
    log_prompt "INFO" && echo "Création de la table GPT"
    parted --script -a optimal /dev/$disk mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }

    local partition_prefix=$([[ "$disk_type" == "nvme" ]] && echo "p" || echo "")

    # Boucle de création des partitions
    for partition_info in "${PARTITIONS_CREATE[@]}"; do
        IFS=':' read -r name size fs_type <<< "$partition_info"
        
        local partition_device="/dev/${disk}${partition_prefix}${partition_number}"

        # Si la taille est "100%", utiliser l'espace restant
        if [[ "$size" == "100%" ]]; then
            # Utilisation de l'espace restant pour la partition
            end="100%"
        else
            # Si ce n'est pas "100%", calculer la fin de la partition
            local start_in_mib=$(convert_to_mib "$start")
            local size_in_mib=$(convert_to_mib "$size")
            local end_in_mib=$((start_in_mib + size_in_mib))
            end="${end_in_mib}MiB"
        fi

        log_prompt "INFO" && echo "Création de la partition $partition_device"
        parted --script -a optimal "/dev/$disk" mkpart primary "$start" "$end" || { 
            echo "Erreur lors de la création de la partition $partition_device"
            exit 1 
        }

        # Gestion des flags spécifiques
        case "$name" in
            "boot") 
                log_prompt "INFO" && echo "Activation de la partition boot $partition_device en mode UEFI"
                parted --script -a optimal "/dev/$disk" set "$partition_number" esp on || { 
                    echo "Erreur lors de l'activation de la partition $partition_device"
                    exit 1 
                }
                ;;

            "swap") 
                log_prompt "INFO" && echo "Activation de la partition swap $partition_device"
                parted --script -a optimal "/dev/$disk" set "$partition_number" swap on || { 
                    echo "Erreur lors de l'activation de la partition $partition_device"
                    exit 1 
                }
                ;;
        esac

        # Formatage des partitions
        log_prompt "INFO" && echo "Formatage de la partition $partition_device en $fs_type"
        case "$fs_type" in
            "btrfs")
                mkfs.btrfs -f -L "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;

            "fat32")
                mkfs.vfat -F32 -n "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;

            "linux-swap")
                mkswap -L "$name" "$partition_device" && swapon "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage ou de l'activation de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;

            *)
                log_prompt "ERROR" && echo "type de fichier non reconnu : $fs_type"
                exit 1
                ;;
        esac

        start="$end"
        ((partition_number++))
    done

}

mount_partitions() {
    
    local disk="$1"
    local partitions=()
    local root_partition=""
    local boot_partition=""
    local home_partition=""
    local other_partitions=()

    # Récupération des partitions du disque
    while IFS= read -r partition; do
        partitions+=("$partition")
    done < <(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | sed -n "s/^[[:graph:]]*${disk}\([0-9]*\)$/${disk}\1/p")

    # Trier et organiser les partitions
    for part in "${partitions[@]}"; do
        local part_label=$(lsblk "/dev/$part" -n -o LABEL)
        case "$part_label" in
            "root") 
                root_partition="$part"
                ;;
            "boot") 
                boot_partition="$part"
                ;;
            "home")
                home_partition="$part"
                ;;
            *)
                other_partitions+=("$part")
                ;;
        esac
    done

    # Monter la partition root EN PREMIER
    if [[ -n "$root_partition" ]]; then
        local NAME=$(lsblk "/dev/$root_partition" -n -o NAME)
        local FSTYPE=$(lsblk "/dev/$root_partition" -n -o FSTYPE)
        local LABEL=$(lsblk "/dev/$root_partition" -n -o LABEL)
        local SIZE=$(lsblk "/dev/$root_partition" -n -o SIZE)

        log_prompt "INFO" && echo "Traitement de la partition : /dev/$NAME (Label: $LABEL, FS: $FSTYPE)"

        # Logique de montage de la partition root (identique à votre script original)
        if [[ "$FSTYPE" == "btrfs" ]]; then
            # Monter temporairement la partition
            mount "/dev/$NAME" "${MOUNT_POINT}"

            # Créer les sous-volumes de base
            btrfs subvolume create "${MOUNT_POINT}/@"
            btrfs subvolume create "${MOUNT_POINT}/@root"
            btrfs subvolume create "${MOUNT_POINT}/@home"
            btrfs subvolume create "${MOUNT_POINT}/@srv"
            btrfs subvolume create "${MOUNT_POINT}/@log"
            btrfs subvolume create "${MOUNT_POINT}/@cache"
            btrfs subvolume create "${MOUNT_POINT}/@tmp"
            btrfs subvolume create "${MOUNT_POINT}/@snapshots"
            
            # Démonter la partition temporaire
            umount "${MOUNT_POINT}"

            # Remonter les sous-volumes avec des options spécifiques
            echo "Montage des sous-volumes Btrfs avec options optimisées..."
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@ "/dev/$NAME" "${MOUNT_POINT}"

            # Créer les sous-répertoires
            mkdir -p "${MOUNT_POINT}/root"
            mkdir -p "${MOUNT_POINT}/home"
            mkdir -p "${MOUNT_POINT}/srv"
            mkdir -p "${MOUNT_POINT}/var/log"
            mkdir -p "${MOUNT_POINT}/var/cache/"
            mkdir -p "${MOUNT_POINT}/tmp"
            mkdir -p "${MOUNT_POINT}/snapshots"

            # Montage des sous-volumes
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@root "/dev/$NAME" "${MOUNT_POINT}/root"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@home "/dev/$NAME" "${MOUNT_POINT}/home"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@tmp "/dev/$NAME" "${MOUNT_POINT}/tmp"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@srv "/dev/$NAME" "${MOUNT_POINT}/srv"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@log "/dev/$NAME" "${MOUNT_POINT}/var/log"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@cache "/dev/$NAME" "${MOUNT_POINT}/var/cache"
            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@snapshots "/dev/$NAME" "${MOUNT_POINT}/snapshots"

        fi
    fi

    # Monter la partition boot 
    if [[ -n "$boot_partition" ]]; then
        local NAME=$(lsblk "/dev/$boot_partition" -n -o NAME)
        mkdir -p "${MOUNT_POINT}/boot"
        mount "/dev/$NAME" "${MOUNT_POINT}/boot"
    fi

    # Monter la partition home 
    if [[ -n "$home_partition" ]]; then
        local NAME=$(lsblk "/dev/$home_partition" -n -o NAME)
        mkdir -p "${MOUNT_POINT}/home"  
        mount "/dev/$NAME" "${MOUNT_POINT}/home"
    fi

    # Monter les autres partitions
    for partition in "${other_partitions[@]}"; do
        local part_label=$(lsblk "/dev/$partition" -n -o LABEL)
        
        # Ignorer la partition swap
        if [[ "$part_label" == "swap" ]]; then
            log_prompt "INFO" && echo "Partition swap déjà monté"
            continue
        fi

        # Ajouter ici toute logique supplémentaire pour d'autres partitions étiquetées différemment
        log_prompt "WARNING" && echo "Partition non traitée : /dev/$partition (Label: $part_label)"
    done
}