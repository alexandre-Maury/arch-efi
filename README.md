# arch-efi

Un script d'installation d'Arch Linux en mode UEFI, conçu pour automatiser les étapes critiques du processus d'installation. 
Il prend en charge le partitionnement GPT, l'installation des paquets de base, la configuration du système et le déploiement du chargeur de démarrage systemd-boot. 
Le script est optimisé pour un système de fichiers btrfs unique.

## Partitionnement automatisé

Utilise une table de partition GPT pour garantir la compatibilité avec les systèmes UEFI.
Partitionnement basé sur des valeurs prédéfinies et modifiables via un fichier de configuration (config.sh).

Les partitions sont configurées comme suit :

    EFI : 512MiB en fat32 avec le drapeau esp activé.
    SWAP : 8GiB en linux-swap (ou une taille définie par l'utilisateur).
    ROOT : Utilise le reste de l'espace disque avec le système de fichiers btrfs.

### Exemple de configuration des partitions dans config.sh

    DEFAULT_BOOT_SIZE="512MiB"
    DEFAULT_SWAP_SIZE="8GiB"
    DEFAULT_FS_SIZE="100%"

    PARTITIONS_CREATE=(
        "boot:${DEFAULT_BOOT_SIZE}:fat32"
        "swap:${DEFAULT_SWAP_SIZE}:linux-swap"
        "root:${DEFAULT_FS_SIZE}:btrfs"
    )
