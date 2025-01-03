# arch-efi

Un script d'installation d'Arch Linux en mode UEFI, conçu pour automatiser les étapes critiques du processus d'installation. 
Il prend en charge le partitionnement GPT, l'installation des paquets de base, la configuration du système et le déploiement du chargeur de démarrage systemd-boot. 
Le script est optimisé pour un système de fichiers btrfs unique.

⚠️ Ce script reste en cours d'amélioration. De nouvelles fonctionnalités et optimisations sont régulièrement ajoutées pour répondre aux besoins des utilisateurs.

## Processus automatisé

Utilise une table de partition GPT pour garantir la compatibilité avec les systèmes UEFI.
Partitionnement basé sur des valeurs prédéfinies et modifiables via un fichier de configuration (config.sh).

Le script utilise btrfs comme système de fichiers exclusif pour la partition racine, garantissant des fonctionnalités modernes telles que la compression, les sous-volumes et les snapshots. Il identifie automatiquement les disque cible (par exemple, /dev/sda) dans un choix proposé à l'utilisateur.

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
La partition ROOT est montée dans /mnt avec des sous-volumes optionnels définis dans config.sh :

    # Liste des sous-volumes BTRFS à créer
    BTRFS_SUBVOLUMES=("@" "@root" "@home" "@srv" "@log" "@cache" "@tmp" "@snapshots")

    # Options de montage BTRFS par défaut
    BTRFS_MOUNT_OPTIONS="defaults,noatime,compress=zstd,commit=120"

### Installation de base :

Installation des paquets essentiels d'Arch Linux (base, linux, linux-firmware, etc.).
    
### Configuration système :
    
Les locales, le fuseau horaire, le clavier, le réseau et d'autres paramètres sont modifiables dans config.sh :

    ZONE="Europe"
    PAYS="France"
    CITY="Paris"
    LANG="fr_FR.UTF-8"
    LOCALE="fr_FR"
    KEYMAP="fr"
    HOSTNAME="archlinux-alexandre"

### Chargeur de démarrage :
    
Déploie et configure systemd-boot en mode EFI pour garantir une compatibilité optimale avec les systèmes modernes.

## Instructions d'utilisation

Clonez le dépôt contenant le script :

    git clone https://github.com/alexandre-Maury/arch-efi.git
    cd arch-efi

Modifiez le fichier config.sh selon vos besoins (présent dans le dossier config) :

    nano config.sh

Lancez le script d'installation :

    chmod +x install.sh && ./install.sh

## Points forts

Optimisé pour btrfs : Exploite les avantages de btrfs, tels que les sous-volumes, la compression, et les snapshots.
Flexibilité : Personnalisation simple via config.sh.
Compatibilité UEFI : Conçu pour fonctionner avec les systèmes modernes utilisant le mode UEFI.
Simplicité : Automatisation complète de l'installation de base d'Arch Linux.

⚠️ Améliorations en cours : Ce script évolue constamment pour intégrer de nouvelles fonctionnalités, améliorer l'ergonomie et renforcer sa robustesse. N'hésitez pas à proposer des idées ou signaler des problèmes via le dépôt GitHub.

## Auteurs

    Alexandre MAURY

## Contribution

    Alexandre MAURY

