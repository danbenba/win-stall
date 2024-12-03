@echo off
if %COMPUTERNAME% NEQ MINWINPC GOTO protect:
set image=%1
set index=%2
set idisk=%3
set wsize=%4
set skip=%5

rem Verification des parametres
IF NOT DEFINED image (
    echo = ERREUR FATALE ===========================================================================
    echo ^(x^) Aucun nom de fichier image defini ! Ceci est necessaire pour specifier la source de l'installation
    echo     a partir de laquelle Windows sera installe. Consultez le fichier readme sur Github pour plus d'infos.
    echo ========================================================================================
    set myexitcode=1
    echo:
    goto usage
)

rem Verification pour afficher l'aide
IF %image% EQU --help (
    set myexitcode=0
    goto usage
)

rem Verifier si le fichier image existe
IF NOT EXIST %image% goto errim

rem Verification du parametre index
IF NOT DEFINED index (
    echo = ERREUR FATALE =======================================================================
    echo ^(x^) Aucun index d'image defini. Cela est important pour choisir l'edition de Windows.
    echo     Comme Home, Pro, etc. Utilisez l'option "--list" pour lister les index de chaque edition.
    echo =====================================================================================
    set myexitcode=1
    echo:
    goto usage
)

title WIN-Stall v0.7 [https://github.com/danbenba/win-stall]
echo ██     ██ ██ ███    ██      ███████ ████████  █████  ██      ██      
echo ██     ██ ██ ████   ██      ██         ██    ██   ██ ██      ██      
echo ██  █  ██ ██ ██ ██  ██ ████ ███████    ██    ███████ ██      ██      
echo ██ ███ ██ ██ ██  ██ ██           ██    ██    ██   ██ ██      ██      
echo  ███ ███  ██ ██   ████      ███████    ██    ██   ██ ███████ ███████  
echo                                                           
echo                     Version 0.7 By danbenba                

rem Afficher la liste des index d'image
IF %index% EQU --list (
    DISM /get-wiminfo /wimfile:%image%
    EXIT /B 0
)

rem Verification des autres parametres
IF NOT DEFINED idisk (
    echo = ERREUR FATALE ===================================================================
    echo ^(x^) Aucun index de disque specifie. Utilisez diskpart et entrez "list disk" pour
    echo     determiner le disque sur lequel installer Windows et la partition de boot EFI.
    echo =================================================================================
    set myexitcode=1
    echo:
    goto usage
)
IF NOT DEFINED wsize (
    echo = ERREUR FATALE =======================================================================
    echo ^(x^) Aucune taille de partition specifiee. Si vous voulez que la partition Windows remplisse
    echo     tout le disque, entrez 0, sinon entrez la taille en Mo.
    echo =====================================================================================
    set myexitcode=1
    echo:
    goto usage
)
IF NOT DEFINED skip (
    set skip=no
)

rem Determiner la taille de la partition Windows
IF %wsize% EQU 0 (
    set wsize=
    set strsize=remplissant tout le disque
) ELSE (
    set wsize=size %4
    set strsize=taille %4 Mo, le reste non partitionne
)

echo install.cmd - Un script permettant d'installer Windows 11 en contournant l'OOBE et d'autres etapes penibles
echo:
echo ^(i^) =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=LES OPERATIONS SUIVANTES SERONT EFFECTUEES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo ^/^!^\ AVERTISSEMENT - POTENTIELLEMENT DESTRUCTEUR DE DONNEES^! ASSUREZ-VOUS QUE LE DISQUE EST VIDE (AUCUNE PARTITION)^!^!
echo:
echo ^=^> Le disque %idisk% sera partitionne et formate comme suit :
echo      1. Une partition EFI de 512 Mo, formatee en FAT32 sera creee (partition de boot)
echo      2. La partition Windows sera creee,
echo         ^-^> %strsize%
echo         ^-^> formatee en NTFS.
echo:
echo ^=^> Windows sera installe en extrayant le contenu de
    %image%
    echo vers la partition Windows creee ci-dessus
echo:
IF /i %skip% EQU no (
    echo ^=^> En copiant le fichier XML non supervise dans \Windows\Panther, l'OOBE sera contourne
echo:
)
IF /i %skip% EQU --skip-oobe echo ^=^> L'OOBE ne sera PAS contourne.
echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo:
echo Vous pouvez annuler cette operation en utilisant CTRL+C, puis en confirmant avec y, ou vous pouvez
pause

rem C'EST PARTI !!
echo ^=^> Partitionnement du disque %idisk% en utilisant diskpart

rem Partitionnement, formatage et assignation des lettres
(echo sel dis %idisk%
echo conv gpt
echo cre par efi size 512
echo form fs fat32 quick
echo ass letter w
echo cre par pri %wsize%
echo form quick
echo ass letter z
) | diskpart >nul
echo:

rem Installation de Windows et de l'environnement de boot
echo ^=^> Installation de Windows a partir de l'image %image% avec l'index %index% sur z:
dism /apply-image /imagefile:%image% /index:%index% /applydir:z:\
IF %ERRORLEVEL% NEQ 0 goto errdism
echo:
echo ^=^> Installation de l'environnement de boot
z:\windows\system32\bcdboot.exe z:\windows /s w:
echo:

rem Copier le XML pour contourner l'OOBE
IF /i %skip% NEQ --skip-oobe (
    echo ^=^> Modification de l'image extraite pour activer le mode non supervise afin de contourner l'OOBE
    echo - Creation du repertoire "Panther" sous z:\Windows
    mkdir z:\Windows\Panther
    echo - Copie du fichier de reponse dans le repertoire Panther precedemment cree
    copy %~dp0\skip_oobe.xml z:\Windows\Panther\unattend.xml
)

echo.
echo Avant de redemarrer, verifiez les journaux pour detecter d'eventuelles erreurs, puis annulez le redemarrage en utilisant CTRL+C ou
pause
echo ^=^> Redemarrage
wpeutil reboot
exit /B 0

rem Gestion des erreurs
:errim
echo = ERREUR FATALE ===============================================================
echo ^(x^) Impossible de trouver le fichier donne ! Assurez-vous que le chemin et le nom du fichier sont corrects.
echo =============================================================================
exit /B 5

:errdism
echo:
echo = ERREUR FATALE ======================================================================
echo ^(x^) Une erreur est survenue lors de l'extraction de l'image^! Veuillez verifier les journaux DISM.
echo ====================================================================================
exit /B 15

:protect
echo = ERREUR FATALE ==============================================================
echo ^/^!^\ Ce script est uniquement destine a fonctionner dans l'environnement Windows PE Setup^!
echo ============================================================================
exit /B 30

:usage
echo install.cmd - Un script permettant d'installer Windows 11 en contournant l'OOBE et d'autres etapes penibles
echo:
echo Usage =-=-=-=-=-=
echo:
echo Ce script est destine a etre utilise sur un disque vierge ! Utilisez diskpart, list disk pour determiner
le disque sur lequel vous voulez installer Windows, puis "sel disk <disque>" pour selectionner le disque et
entrez "clean" pour SUPPRIMER TOUS LES FICHIERS ET PARTITIONS.
echo:
echo ^/^!^\ Il n'y a aucune verification si le disque est vierge. Utilisez a vos risques et perils !
echo:
echo -- Lister les index / editions Windows disponibles --
echo install <chemin vers install.esd ou install.wim> --list
echo:
echo -- Installer Windows --
echo Parametres (l'ordre est important !) :
echo 1: chemin vers install.esd ou install.wim
echo 2: index de l'image
echo 3: index du disque de destination via diskpart
echo 4: taille de la partition Windows en Mo - 0 = remplir le disque
echo 5: --skip-oobe - utilisez ceci pour contourner l'OOBE
echo:
echo Exemples :
echo Installer Windows a partir de g:\sources\install.esd sur le disque 0 avec l'index 6 (par exemple Win11 Pro)
echo et limiter la taille de la partition Windows a 512 Go :
echo install g:\sources\install.esd 6 0 524288
echo:
echo Installer Windows a partir de g:\sources\install.esd sur le disque 0 avec l'index 6 (par exemple Win11 Pro)
echo et laisser la partition Windows remplir le disque :
echo install g:\sources\install.esd 6 0 0
echo:
echo Installer Windows a partir de g:\sources\install.esd sur le disque 0 avec l'index 6 (par exemple Win11 Pro)
echo et limiter la taille de la partition Windows a 512 Go mais en contournant l'OOBE :
echo install g:\sources\install.esd 6 0 524288 --skip-oobe
exit /B %myexitcode%
