# arch-efi

Un script d'installation d'Arch Linux en mode UEFI, conçu pour automatiser les étapes critiques du processus d'installation. 
Il prend en charge le partitionnement GPT, l'installation des paquets de base, la configuration du système et le déploiement du chargeur de démarrage systemd-boot. 
Le script est optimisé pour un système de fichiers btrfs unique.

## Processus automatisé

Détection du disque : Identifie le disque cible (par exemple, /dev/sda) pour appliquer le partitionnement GPT.

Utilise une table de partition GPT pour garantir la compatibilité avec les systèmes UEFI.
Partitionnement basé sur des valeurs prédéfinies et modifiables via un fichier de configuration (config.sh).

Le script utilise btrfs comme système de fichiers exclusif pour la partition racine, garantissant des fonctionnalités modernes telles que la compression, les sous-volumes et les snapshots.

Les partitions sont configurées comme suit :

    EFI : 512MiB en fat32 avec le drapeau esp activé.
    SWAP : 8GiB en linux-swap (ou une taille définie par l'utilisateur).
    ROOT : Utilise le reste de l'espace disque avec le système de fichiers btrfs.

### Exemple de configuration des partitions dans config.sh

    DEFAULT_BOOT_TYPE="fat32"
    DEFAULT_SWAP_TYPE="linux-swap"
    DEFAULT_FS_TYPE="btrfs"

    DEFAULT_BOOT_SIZE="512MiB"
    DEFAULT_SWAP_SIZE="8GiB"
    DEFAULT_FS_SIZE="100%"

    PARTITIONS_CREATE=(
        "boot:${DEFAULT_BOOT_SIZE}:${DEFAULT_BOOT_TYPE}"
        "swap:${DEFAULT_SWAP_SIZE}:${DEFAULT_SWAP_TYPE}"
        "root:${DEFAULT_FS_SIZE}:${DEFAULT_FS_TYPE}"
    )

### Montage des partitions :

La partition EFI est montée dans /mnt/boot.
La partition ROOT est montée dans /mnt avec des sous-volumes optionnels si activés. Modifiables via le fichier de configuration (config.sh)

    # Liste des sous-volumes BTRFS à créer
    BTRFS_SUBVOLUMES=("@" "@root" "@home" "@srv" "@log" "@cache" "@tmp" "@snapshots")

    # Options de montage BTRFS par défaut
    BTRFS_MOUNT_OPTIONS="defaults,noatime,compress=zstd,commit=120"

### Installation de base :

Installation des paquets essentiels d'Arch Linux (base, linux, linux-firmware, etc.).
    
### Configuration système :
    
Locales, fuseau horaire, clavier, réseau et autres paramètres : modifiables via le fichier de configuration (config.sh)

    ZONE="Europe"
    PAYS="France"
    CITY="Paris"
    LANG="fr_FR.UTF-8"
    LOCALE="fr_FR"
    KEYMAP="fr"
    HOSTNAME="archlinux-alexandre"

### Chargeur de démarrage :
    
Déploiement et configuration de systemd-boot en mode EFI.