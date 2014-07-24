#!/bin/sh

# Copyright 2014 Kevin Lagaisse
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


# This script rename, move and index TV show files on Synology NAS
#  Must be used with TVRenamr, a python script by George Hickman
#  You can find the script at http://tvrenamr.info/



dlPath="/volume1/Famille/telechargements/kevin/"
configPath="/volume1/Famille/telechargements/config.yml"

#find ${dlPath} -type f -name *.avi -exec tvr --log-level=debug --config=${configPath} '{}' \;


#renommer les fichiers en enlevant le début du nom du fichier qui serait en "[toto] "

testpath="/volume1/Famille/telechargements/kevin/dummy file for test.avi"
find ${dlPath} -type f -name "*.avi" -o -name "*.mp4" | while read filepath
#echo $testpath | while read filepath
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
   mv -f "$filepath" "$newfilepath"
   #-n new_filepath old_filepath
   #rename a file
   synoindex -n "$newfilepath" "$filepath"

  fi
done


# Lancer l'indexation des séries et les déplacer dans leur répertoire
find ${dlPath} -type f -name "*.avi" -o -name "*.mp4" | while read originalPath
#echo $testpath | while read originalPath
do
    echo
    echo

    echo "#INDEXATION#"
    echo "Fichier : "$originalPath


    originalName=$(basename "$originalPath")

    tvr --log-level=minimal --config=${configPath} "$originalPath" 2>"log/$originalName.log"

    destinationDir=$(sed -nr -e 's/^Directory: (.+)$/\1/p' "log/$originalName.log")
    destinationName=$(sed -nr -e 's/Renamed: "(.+)"$/\1/p' "log/$originalName.log")
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
		destinationNbFiles=$(find "${destinationDir}" -type f -maxdepth 1 -name "*.avi" -o -name "*.mp4" | wc -l)
		if test "$destinationNbFiles" -gt 1
		then
			echo "Mise à jour de l'index : TVShow deja dans l'index, presence d'autres episodes"
		    echo "Mise à jour de l'index : Ajout de l'episode à l'index"
			synoindex -n "$destinationPath" "$originalPath"
		else
			destinationBaseDir=$(dirname "${destinationDir}/")
			echo $destinationBaseDir
			destinationNbDirBaseDir=$(find "${destinationBaseDir}" -type d -maxdepth 1 | wc -l)
			if test "$destinationNbDirBaseDir" -gt 1				
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
        

    fi


    #rm "log/$originalName.log"
done


