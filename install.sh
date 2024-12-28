#!/bin/bash

# script install.sh
# Ce script constitue le point d'entrée pour l'installation, 
# en regroupant les fichiers de configuration et fonctions nécessaires.

set -e  
# Active le mode "exit on error". Si une commande retourne une erreur, le script s'arrête immédiatement.
# Cela garantit que les étapes critiques ne sont pas ignorées.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Détermine le chemin absolu du répertoire contenant ce script.
# Cette approche rend le script portable et lui permet de toujours localiser les fichiers nécessaires,
# quel que soit le répertoire à partir duquel il est exécuté.

source $SCRIPT_DIR/config/config.sh
# Charge le fichier de configuration situé dans le sous-dossier config.

source $SCRIPT_DIR/functions/functions.sh  
# Charge un fichier contenant des fonctions utilitaires génériques.

source $SCRIPT_DIR/functions/functions_disk.sh  
# Charge un fichier contenant des fonctions spécifiques à la gestion des disques.

source $SCRIPT_DIR/functions/functions_install.sh  
# Charge un fichier contenant des fonctions dédiées à l'installation du système.

