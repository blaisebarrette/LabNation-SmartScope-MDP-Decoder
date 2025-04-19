# Guide de Référence pour le Décodage MDB avec un Oscilloscope

Ce document fournit les informations essentielles pour comprendre et décoder le protocole de communication Multi-Drop Bus (MDB) à l'aide d'un oscilloscope. Il sert d'outil de référence pour la programmation d'un décodeur MDB en fournissant les détails nécessaires sur la couche physique, le protocole de communication, la temporisation et la structure des commandes.

## 1. Introduction

Le protocole MDB est une norme utilisée principalement dans l'industrie de la distribution automatique pour la communication entre le contrôleur principal de la machine (VMC - Vending Machine Controller) et divers périphériques tels que les accepteurs de pièces, les validateurs de billets, les lecteurs de cartes sans contact, les distributeurs de monnaie, etc. L'oscilloscope est un outil précieux pour visualiser et analyser les signaux électriques sur le bus MDB, ce qui est crucial pour le débogage et la mise au point d'un décodeur.

## 2. Couche Physique

La couche physique du bus MDB définit les caractéristiques électriques et mécaniques de l'interface.

*   **Alimentation du Bus :** Le VMC fournit une alimentation de **+5 VDC** aux périphériques. Les besoins en courant spécifiques de chaque périphérique sont définis dans leurs sections respectives.
*   **Niveaux Logiques :** Bien que le bus soit alimenté en +5 VDC, les **spécifications exactes des seuils de tension** pour considérer un signal comme étant à l'état logique haut (High) ou bas (Low) **ne sont pas fournies explicitement dans les extraits de source utilisés pour cette mise à jour**. Ces détails se trouveraient normalement dans la spécification complète de l'interface matérielle MDB. Pour la visualisation à l'oscilloscope, attendez-vous à des signaux proches de 0V (bas) et +5V (haut).
*   **Spécifications de l'Émetteur/Récepteur :** Les détails précis sur les caractéristiques électriques des émetteurs et récepteurs du bus sont définis dans la spécification.
*   **Spécifications du Connecteur :** La spécification du connecteur MDB, y compris les schémas des connecteurs mâles et femelles, est détaillée dans la spécification.
*   **Schéma d'Exemple :** Un schéma d'exemple illustrant la connexion entre le VMC et plusieurs périphériques (Slaves) est fourni. On y voit les lignes **+5 VDC**, **Master Transmit**, **Master Receive**, et **Communications Common** connectées entre le VMC et les périphériques via des portes CMOS.

## 3. Protocole de Communication

Le protocole MDB est un protocole de communication série asynchrone multi-drop basé sur une architecture maître-esclave.

*   **Architecture Maître-Esclave :** Le **VMC agit comme le maître** et initie toutes les communications avec les périphériques (esclaves). Les périphériques ne communiquent qu'en réponse aux commandes du maître.
*   **Adressage :** Chaque périphérique sur le bus MDB possède une adresse unique.
    *   L'octet d'adresse est le premier octet d'un bloc de communication maître-vers-périphérique.
    *   Les **cinq bits supérieurs (MSB) de l'octet d'adresse sont utilisés pour l'adressage**, permettant d'adresser jusqu'à 32 périphériques (2^5).
    *   Les **trois bits inférieurs de l'octet d'adresse contiennent des instructions spécifiques au périphérique**, permettant jusqu'à huit instructions intégrées dans le premier octet.
    *   L'adresse du **VMC est 00000xxxB (00H)**. Des exemples d'adresses de périphériques incluent le changeur (08H), le validateur de billets (30H) et le dispositif satellite universel (USD) (par exemple, 40H, 48H, 50H).

*   **Format de la Trame Série (UART) :** La communication série suit un format spécifique pour chaque octet transmis :
    *   **Bit de Start : 1 bit** (niveau bas).
    *   **Bits de Données : 8 bits**.
    *   **Bit de Mode : 1 bit**. Ce 9ème bit suit les 8 bits de données et précède le bit de stop.
        *   *Maître vers Périphérique :* Ce bit est utilisé pour distinguer un octet d'adresse (Mode Bit = 1) d'un octet de données (Mode Bit = 0).
        *   *Périphérique vers Maître :* Ce bit doit être mis à 1 sur le dernier octet du bloc de données envoyé par le périphérique avant l'octet CHK (ou sur le dernier octet si pas de CHK comme pour ACK/NAK). Pour tous les autres octets de données, il est à 0.
    *   **Bit de Parité : Aucun**. Le protocole MDB n'utilise pas de bit de parité.
    *   **Bit de Stop : 1 bit** (niveau haut).
    *   Chaque octet transmis sur le bus MDB est donc encadré par 1 bit de Start, 1 bit de Mode et 1 bit de Stop, pour un total de 11 bits par octet. L'état de la ligne au repos (Idle) est typiquement Haut (High).

*   **Format des Blocs de Communication :**
    *   **Maître vers Périphérique :** Un bloc comprend un **octet d'adresse** (avec le Mode Bit à 1), des **octets de données optionnels** (Mode Bit à 0, maximum 31 octets), et un **octet de contrôle de redondance cyclique (CHK)** (Mode Bit à 0). La taille maximale d'un bloc est de 36 octets (1 Adresse + 34 Données max + 1 CHK).
    *   **Périphérique vers Maître :** Un bloc comprend soit un **bloc de données (un ou plusieurs octets de données, Mode Bit à 0 sauf pour le dernier octet où il est à 1) suivi d'un octet CHK** (Mode Bit à 0), soit un **octet d'accusé de réception (ACK)** (00H avec Mode Bit à 1), soit un **octet d'accusé de réception négatif (NAK)** (FFH avec Mode Bit à 1). Un octet CHK n'est pas requis pour les réponses ACK ou NAK. La taille maximale d'un bloc de données et de l'octet CHK est de 36 octets.

*   **Calcul du Checksum (CHK) :** L'octet CHK est utilisé pour vérifier l'intégrité des données transmises.
    *   Le **CHK est la somme modulo 256 (somme sur 8 bits) de tous les octets de données** du bloc.
    *   Pour un bloc Maître vers Périphérique, l'octet d'Adresse est **aussi** inclus dans le calcul de la somme.
    *   Pour un bloc Périphérique vers Maître, le calcul inclut **uniquement les octets de données** (pas d'octet d'adresse implicite dans le calcul).
    *   L'octet CHK lui-même n'est **jamais inclus** dans le calcul de sa propre somme.
    *   Les **retenues (carry bits) au-delà du 8ème bit sont ignorées**.
    *   *Exemple (basé sur celui fourni) :* Pour une réponse de statut d'un changeur contenant plusieurs octets de données (par exemple, 02H, 00H, 01H, 05H, 02H, 00H, 07H, 01H, 02H, 05H, 14H, FFH), la somme de ces octets donne 2CH. Ce 2CH serait envoyé comme l'octet CHK à la fin de ce bloc de données.
    *   Un calcul de checksum n'est **pas effectué** sur les réponses simples d'un seul octet comme ACK ou NAK.

*   **Acquittements (ACK) et Acquittements Négatifs (NAK) :**
    *   Un **ACK (00H avec Mode Bit à 1)** est envoyé par le périphérique pour indiquer qu'il a reçu et compris une commande ou un bloc de données du maître, ou pour indiquer qu'il n'a pas d'activité à signaler en réponse à un POLL.
    *   Un **NAK (FFH avec Mode Bit à 1)** est envoyé par le périphérique pour indiquer qu'il n'a pas pu traiter la commande (par exemple, erreur de checksum, commande invalide, état occupé).
    *   Le VMC répond aux données d'un périphérique (sauf ACK/NAK) par un ACK, un NAK ou une demande de retransmission (RET - non détaillé ici).
    *   Un délai d'attente de **5 ms (t-response)** sans réponse du périphérique après une commande est interprété comme un NAK par le maître.
    *   Il est recommandé que le périphérique traite un délai d'attente après réception de l'octet d'adresse comme un NAK interne pour éviter des réponses NAK simultanées sur le bus. Les nouveaux périphériques ne devraient jamais envoyer de NAK explicite.

*   **Ordre des Octets :** Lors des messages multi-octets, **l'octet le plus significatif (MSB) est envoyé en premier** pour les valeurs numériques (par exemple, montants, compteurs). L'ordre des octets dans un bloc de communication suit la séquence Adresse (si Maître->Périph.), Données, CHK.
*   **Bits Non Définis :** Tous les bits ou octets non spécifiquement définis dans une commande ou une réponse doivent être laissés à l'état 0.

## 4. Temporisation

Le respect des spécifications de temporisation est essentiel pour une communication MDB fiable.

*   **Débit Binaire (Baud Rate) :** **9600 bits par seconde**, avec une tolérance de +1%/-2%.
*   **Temporisation des Bits (t) :** Environ 104 µs par bit (1 / 9600 bps).
*   **Temporisation Inter-Octets (t inter-byte) :** Maximum **1.0 ms** lors de l'envoi (entre la fin du bit de stop d'un octet et le début du bit de start du suivant). Maximum **5.0 ms** lors de la réception. Un dépassement du délai inter-octets lors de la réception d'un bloc de données par un périphérique indique la fin du bloc.
*   **Temporisation de Réponse (t response) :** Maximum **5.0 ms** pour la réponse immédiate d'un périphérique (ACK, NAK, ou début d'un bloc de données) après la réception complète d'une commande du maître (après le bit de stop du dernier octet ou du CHK). Cependant, les périphériques ont l'option de ne pas répondre immédiatement si une opération plus longue est en cours (voir Temps de Non-Réponse). Le VMC doit attendre 5ms avant de conclure à un NAK implicite si aucune réponse n'est reçue.
*   **Condition de Break (t break) :** Minimum **100 ms** pour un "master reset" initié par le VMC en tirant la ligne de transmission maître (TX) à l'état bas (actif).
*   **Temps de Configuration (t setup) :** Minimum **200 ms** d'attente après la fin d'une condition de break avant que le VMC n'envoie la première commande (typiquement RESET).
*   **Temps de Non-Réponse :** Le temps maximal pendant lequel un périphérique peut ne pas répondre à une commande ou à un POLL (par exemple, en restant silencieux ou en répondant ACK à des POLL successifs) pendant qu'il effectue une tâche interne. Ce temps est défini dans les spécifications de chaque périphérique (par exemple, 5 secondes pour le validateur de billets). Le périphérique doit répondre dans ce délai imparti.
*   **Répétition des Commandes :** Les commandes VMC non acquittées (NAK implicite ou explicite) doivent être répétées pendant la durée du délai de non-réponse ou jusqu'à réception d'un ACK. Pour les commandes autres que POLL, il est recommandé d'alterner la commande avec un POLL.

## 5. Commandes et Réponses

Le protocole MDB comprend un ensemble de commandes que le VMC utilise pour interagir avec les périphériques. Chaque périphérique a son propre ensemble de commandes spécifiques.

*   **Format Général des Commandes :** Une commande peut être implicite dans les trois bits inférieurs de l'octet d'adresse ou être spécifiée par des octets de données suivant l'octet d'adresse. Certaines commandes utilisent un format avec un **code de commande principal** suivi d'un **code de sous-commande** et éventuellement de données supplémentaires (par exemple, la commande EXPANSION).
*   **Commandes Générales :**
    *   **RESET (Adresse + Commande 0, ex: 08H pour changeur) :** Commande pour qu'un périphérique s'auto-réinitialise et revienne à son mode de fonctionnement par défaut. Après une réinitialisation (RESET ou Break), une séquence d'initialisation est recommandée. Le périphérique doit répondre ACK dans les 5ms après réception du RESET. Un délai supplémentaire (ex: 200ms après Break) est nécessaire avant d'envoyer d'autres commandes. Après une réinitialisation, le périphérique répondra typiquement "JUST RESET" (00H) au premier POLL.
    *   **SETUP (Adresse + Commande 1, ex: 09H pour changeur) :** Commande pour demander des informations de configuration au périphérique. La réponse contient des informations telles que le niveau de fonctionnalité, les facteurs d'échelle, les décimales, les codes de devise, etc.
    *   **POLL (Adresse + Commande 3, ex: 0BH pour changeur) :** Commande pour demander l'état d'activité du périphérique. La réponse peut être ACK (pas d'événement), "JUST RESET" (00H), ou signaler divers événements spécifiques au périphérique (par exemple, une pièce insérée, un billet validé, une erreur).
*   **Commandes Spécifiques aux Périphériques (Exemples) :**
    *   **Changeur de Pièces (Adresse 08H) :** SETUP (09H), TUBE STATUS (0AH), POLL (0BH), COIN TYPE (0CH), DISPENSE (0DH), EXPANSION (0FH). La commande EXPANSION (0FH) utilise des sous-commandes pour des fonctions étendues (ex: 00H pour ID Fabricant, 05H pour Diagnostic).
    *   **Validateur de Billets (Adresse 30H) :** RESET (30H), SETUP (31H), SECURITY (32H), POLL (33H), BILL TYPE (34H), ESCROW (35H), STACKER (36H), EXPANSION (37H). EXPANSION (37H) avec sous-commandes permet l'identification, l'activation de fonctionnalités, etc.
    *   **Universal Satellite Device (USD) (Ex: Adresse 40H) :** RESET (40H), SETUP (41H), POLL (43H - utilisé différemment selon le mode), VEND (43H), READER ENABLE/DISABLE (44H), CONTROL (45H), EXPANSION (47H).
    *   **Distributeur de Monnaie (Hopper/Tube) (Ex: Adresse 58H/70H) :** RESET (58H/70H), SETUP (59H/71H), DISPENSER STATUS (5AH/72H), POLL (5BH/73H), MANUAL DISPENSE ENABLE (5CH/74H), EXPANSION (5FH/77H).
*   **File Transport Layer (FTL) :** Le protocole MDB inclut une couche de transport de fichiers (FTL) utilisant des sous-commandes spécifiques sous EXPANSION (par exemple, FEH - REQ TO SEND, FAH - REQ TO RCV) pour transférer des données plus volumineuses.

## 6. Utilisation de l'Oscilloscope

L'oscilloscope vous permettra de visualiser les signaux sur les lignes MDB et de vérifier leur conformité avec les spécifications.

*   **Connexion des Sondes :** Connectez les sondes de l'oscilloscope aux lignes **Master Transmit (VMC TX)** et **Master Receive (VMC RX)**, ainsi qu'à la masse commune (Communications Common). Utilisez au moins deux canaux pour voir la communication dans les deux sens.
*   **Configuration de l'Oscilloscope :**
    *   Réglez le couplage sur DC.
    *   Ajustez la base de temps pour visualiser des octets individuels (ex: 500 µs/div) ou des blocs entiers (ex: 5 ms/div).
    *   Ajustez l'échelle verticale pour voir clairement les niveaux 0V et +5V.
*   **Déclenchement (Triggering) :**
    *   Déclenchez sur le front descendant du bit de démarrage sur l'une des lignes (TX ou RX).
    *   Utilisez le déclenchement sur motif (Pattern Triggering) ou série (Serial Triggering) si votre oscilloscope le permet, pour isoler des octets spécifiques (ex: un octet d'adresse).
    *   Déclenchez sur une condition de Break (long niveau bas sur VMC TX).
*   **Mesure de la Temporisation :** Utilisez les curseurs de l'oscilloscope pour mesurer :
    *   La durée d'un bit (devrait être ~104 µs pour 9600 bps).
    *   Le délai inter-octets (t inter-byte).
    *   Le temps de réponse du périphérique (t response) entre la fin de la commande maître et le début de la réponse esclave.
    *   La durée de la condition de Break (t break).
*   **Décodage Visuel et Automatique :**
    *   Analysez la forme d'onde bit par bit : Start (bas), 8 Data (LSB d'abord), Mode, Stop (haut).
    *   Identifiez les octets d'adresse (Mode Bit = 1) et de données (Mode Bit = 0) dans les trames Maître->Périphérique.
    *   Repérez le dernier octet de données d'une réponse Périphérique->Maître (Mode Bit = 1).
    *   Utilisez la fonction de décodage série (UART/RS232) de l'oscilloscope si disponible, en configurant 9600 bauds, 8 bits de données, pas de parité, 1 bit de stop. Note : Le décodeur standard pourrait ne pas interpréter correctement le 9ème bit (Mode Bit) ; une analyse manuelle ou un script de décodage peut être nécessaire pour ce bit.
*   **Analyse des Blocs :** Observez la structure : Adresse, Données (si présentes), CHK. Vérifiez la présence et la valeur du CHK. Identifiez les réponses ACK (souvent 00H avec Mode Bit 1) et NAK (souvent FFH avec Mode Bit 1).

## 7. Conseils et Bonnes Pratiques

*   **Respecter la Temporisation :** Assurez-vous que votre décodeur respecte scrupuleusement les spécifications de temporisation MDB, y compris les délais minimum et maximum.
*   **Gestion du Bit de Mode :** Implémentez correctement la logique pour envoyer et interpréter le 9ème bit (Mode Bit). C'est crucial pour distinguer les adresses/données et la fin des blocs.
*   **Calcul du Checksum :** Implémentez précisément l'algorithme de calcul du CHK, en incluant l'octet d'adresse pour les transmissions maître->périphérique et en l'excluant pour périphérique->maître.
*   **Gestion des Acquittements :** Gérez correctement les réponses ACK et NAK (explicites et implicites par timeout). Notez la recommandation que les nouveaux périphériques n'envoient pas de NAK.
*   **Séquence d'Initialisation :** Après une réinitialisation (RESET ou break), suivez la séquence : attente de l'ACK au RESET, POLL jusqu'à obtenir "JUST RESET", puis envoyer SETUP et traiter la réponse.
*   **Compatibilité des Niveaux :** Soyez conscient des différents niveaux de fonctionnalité (Level 1, 2, 3...). Le VMC doit interroger le niveau du périphérique (via SETUP) et n'utiliser que les commandes compatibles.
*   **Traitement des Réponses Multiples :** En réponse à un POLL, un périphérique peut envoyer plusieurs informations sous forme d'un bloc de données. Le VMC doit pouvoir parser ce bloc entier. Le dernier octet de données aura son Mode Bit à 1.
*   **Gestion des Erreurs :** Prévoyez la gestion des erreurs : timeouts (NAK implicite), erreurs de checksum (ignorer le bloc ou demander une retransmission si VMC), commandes inattendues ou hors séquence (souvent résolu par un RESET du périphérique).

## 8. Conclusion

Le développement d'un décodeur MDB, ou le débogage d'une communication MDB, nécessite une compréhension précise des spécifications du protocole : couche physique (niveaux, timing), format de trame série (incluant le bit de mode), structure des blocs (adresse, données, CHK), et séquences de commandes/réponses. L'oscilloscope est un outil indispensable pour visualiser ces éléments directement sur le bus, vérifier la conformité temporelle et logique, et diagnostiquer les problèmes. Ce guide, complété des détails sur le calcul du checksum et le format de trame, fournit une base solide pour aborder le décodage MDB. Référez-vous toujours à la spécification officielle MDB/ICP pour les détails définitifs et spécifiques à chaque type de périphérique.