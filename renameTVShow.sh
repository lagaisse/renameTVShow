#!/bin/sh

# Copyright 2016 Kevin Lagaisse
# 
# Licensed under the Creative Commons BY-NC-SA 4.0 licence (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://creativecommons.org/licenses/by-nc-sa/4.0/
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This script renames, moves and indexes TV show files on Synology NAS
#  Must be used with TVRenamr, a python script by George Hickman
#  You can find the script at http://tvrenamr.info/

# TODO 2 : Ajouter les mkv ?
# TODO 3 : Ajouter un numero de version et licence

version() {
    echo "$0" # TODO 3
}

usage() {
    programName=$(basename "$0")
    echo "" 1>&2
    echo "Usage    : ${programName} DLPATH CONFPATH [force [forceroot]]" 1>&2
    echo "" 1>&2
    echo "Startup:" 1>&2
    echo "    DLPATH   : root directory where the files are stored (inline or in an individual directory)" 1>&2
    echo "    CONFPATH : path to the config file config.yml of the tvrenamr script" 1>&2
    echo "               see tvrenamr help for details" 1>&2
    echo "    force    : (true or false) indicate if the script should ignore previous indexation, based on the log file presence" 1>&2
    echo "               false by default" 1>&2
    echo "    forceroot: (true or false) indicate if the script should allow the run by root, because of the use of the rm cmd" 1>&2
    echo "               false by default" 1>&2
    exit 1
}

dlpathperror() {
    echo "Error : dlPath is not a path" 1>&2
    usage
}

configfileperror() {
    echo "Error : config file not found" 1>&2
    usage
}

forceperror() {
    echo "Error : wrong force parameter value" 1>&2
    usage
}


forbidrootrun() {
    if test "$(id -u)" = "0" 
    then
       echo "This script shouldn't be run as root" 1>&2
       usage
    fi
}

paramnberror() {
    echo "Error : program needs at least 2 parameters" 1>&2
    usage
}

checksynoindex() {
    synoLoc=$(which "synoindex")
    if test -z "$synoLoc"
    then
        echo "Error : synoindex command is not present. Are you sure you're running this program on a synology-branded NAS device ?" 1>&2
        exit 1
    fi
}

checkpython() {
    pythonLoc=$(which "python")
    if test -z "$pythonLoc"
    then
        pythonexe="/var/packages/python/target/bin/python"
        if test ! -f "$pythonexe"
        then
            echo "Error : python command is not present. Are you sure you've installed python ?" 1>&2
            echo "        Please refer to https://synocommunity.com/ to install the package from the package center" 1>&2
            echo "        python is used by the tvrenamr program used in this script" 1>&2
            exit 1
        else
            echo "Error : link for python is not present in /usr/bin" 1>&2
            echo "        It may be because of a device update" 1>&2
            echo "        Please run :   ln -s /var/packages/python/target/bin/python /usr/bin/python" 1>&2
            exit 1
        fi
    fi
}

checktvrenamr() {
    tvrLoc=$(which "tvr")
    if test -z "$tvrLoc"
    then
        tvrexe="/var/packages/python/target/bin/tvr"
        if test ! -f "$tvrexe"
        then
            echo "Error : tvr command is not present. Are you sure you've installed tvrenamr ?" 1>&2
            echo "        Please refer to http://tvrenamr.info/ for install instructions" 1>&2
            exit 1
        else
            echo "Error : link for tvr is not present in /usr/bin" 1>&2
            echo "        It may be because of a device update" 1>&2
            echo "        Please run   ln -s /var/packages/python/target/bin/tvr /usr/bin/tvr" 1>&2
            exit 1
        fi
    fi
}

findFiles() {
    local path="$1"
    find "${path}" -type f -name "*.avi" -o -name "*.mp4"
}

findEpisodes() {
    local path="$1"
    find "${path}" -type f -maxdepth 1 -name "*.avi" -o -name "*.mp4"
}

checksynoindex
checkpython
checktvrenamr

if test $# -lt 2
then
    paramnberror
fi
dlPath=$(echo "$1"|tr -s '/')
dlPath=$(echo "${dlPath%/}")
configPath=$(echo "$2"|tr -s '/')

if test ! -d "$dlPath"
then
    dlpathperror
fi

if test ! -f "$configPath"
then
    configfileperror
fi


forceIndex=false

if test $# -ge 3
then
    if test $3 = "true"
    then
        forceIndex=true
    else
        if test $3 = "false"
        then
            forceIndex=false
        else
            forceperror
        fi
    fi
else
    forceIndex=false
fi


if test $# -eq 4
then
    if test $4 != "true"
    then
        forbidrootrun
    fi
else
    forbidrootrun
fi

#renommer les fichiers en enlevant le début du nom du fichier qui serait en "[toto] nom du fichier"

findFiles "${dlPath}" | while read filepath
do
    echo
    echo

    echo "#RENOMMAGE#"
    echo "Fichier : "$filepath

    filename=$(basename "$filepath")
    newfilename=$(echo "$filename"|sed -r 's/^(\[[^]]+] )(.+)$/\2/gI')
    filedir=$(dirname "$filepath")
    newfilepath="$filedir/$newfilename"

    echo "Ancien nom : $filename"
    echo "Nouveau nom : $newfilename"
    echo "Nouveau fichier : $newfilepath"

  if test "$newfilename" = "$filename"
  then
   echo "Action : aucune"
  else
   echo "Action : RENOMMER ET REINDEXER"
   synoindex -d  "$filepath"
   mv -f "$filepath" "$newfilepath"
   #-n new_filepath old_filepath
   #rename a file
   synoindex -a "$newfilepath"

  fi
done


# Lancer l'indexation des séries et les déplacer dans leur répertoire
findFiles "${dlPath}" | while read originalPath
do
    echo
    echo

    echo "#INDEXATION#"
    echo "Fichier : "$originalPath

    originalName=$(basename "$originalPath")
    originalDir=$(dirname "$originalPath")
    logPath="$originalDir/$originalName.log"

#Verifier s'il n'existe pas déjà un fichier de log 
# s'il existe un fichier de log, passer au fichier suivant
# option forceIndex pour bypasser la presence d'un fichier de log
    if $forceIndex || test ! -f "$logPath"
    then
        tvr --log-level=minimal --config=${configPath} "$originalPath" 2>"$logPath"

        destinationDir=$(sed -nr -e 's/^Directory: (.+)$/\1/p' "$logPath")
        destinationName=$(sed -nr -e 's/Renamed: "(.+)"$/\1/p' "$logPath")
        destinationPath="$destinationDir/$destinationName"
        if test "$destinationDir" = "" -o "$destinationName" = ""
        then
            echo "SKIPPED : Fichier non trouvé dans tvdb"
        else
            echo "Répertoire destination : $destinationDir"
            echo "Nouveau nom : $destinationName"
            echo "Nouveau chemin : $destinationPath"

            #Déplacer l'index sur le nouveau fichier
            #Si le répertoire est nouvellement créé (nb fichiers = 1) alors ajouter le répertoire à l'index
            ##Si le répertoire du TVShow n'est pas dans l'index, alors l'ajouter
            #Sinon signaler a l'index le déplacement du fichier
            destinationNbFiles=$(findEpisodes "${destinationDir}" | wc -l)
            if test "$destinationNbFiles" -gt 1
            then
                echo "Mise à jour de l'index : TVShow deja dans l'index, presence d'autres episodes"
                echo "Mise à jour de l'index : Ajout de l'episode à l'index"
                #synoindex -n "$destinationPath" "$originalPath"
                synoindex -d "$originalPath"
                synoindex -a "$destinationPath"
            else
                destinationBaseDir=$(dirname "${destinationDir}/")
                echo $destinationBaseDir
                destinationNbDirBaseDir=$(find "${destinationBaseDir}" -type d -maxdepth 1 | wc -l)
                if test "$destinationNbDirBaseDir" -gt 2 # Me and my child                
                then
                    echo "Mise à jour de l'index : TVShow deja dans l'index, nouvelle saison uniquement"
                else
                    echo "Mise à jour de l'index : Ajout du TVShow dans l'index"
                    synoindex -A "$destinationBaseDir"        
                fi
                echo "Mise à jour de l'index : Ajout de la saison à l'index"
                synoindex -A "$destinationDir"
                synoindex -d "$originalPath"
            fi
            
            #Suppression des répertoires dans lesquels se trouvaient les fichiers 
            # Verifier que le repertoire d'origine n'est pas egal au répertoire racine de l'éxecution du script
            #  si ce n'est pas le repertoire racine
            #   supprimer le repertoire avec tout ce qui se trouve dedans sauf si presence d'autres videos 
            #  si c'est le répertoire racine alors ne supprimer que le fichier de log
            if test "$originalDir" != "$dlPath"
            then
                originalNbFiles=$(findFiles "${originalDir}" | wc -l)
                if test "$originalNbFiles" -lt 1
                then
                    echo "Suppression du repertoire original et de son contenu : $originalDir"
                    rm -Rf "$originalDir"
                    synoindex -D "$originalDir"
                else
                    echo "Pas de suppression du répertoire : présence de videos dans $originalDir"
                fi
            else
                echo "Suppression du fichier log uniquement : $logPath"
                rm -f "$logPath"
            fi
        fi
        #concervation du fichier de log en cas d'erreur afin de le traiter à la main
        #en cas de relance sans option de forcage, le fichier ne sera pas traité à nouveau
    else
        echo "SKIPPED : fichier non present dans tvdb lors de la session precedente"
    fi
done

exit 0
