# Author		: Łukasz Nowakowski
# Created on		: 06.05.2022
# Last Modified By	: Łukasz Nowakowski
# Last Modified On	: 13.05.2022
# Version		: 1.0.1
#
# Description		: Script generates html report based on found key words in mozilla firefox browser history. 
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details or contact the Free Software Foundation for a copy)

version="1.0.1"
menu=("Generuj raport" "Dodaj słowa kluczowe" "Statystyki i monitoring" "Ustawienia raportu")
addKeyWordMenu=("Dodaj kategorię" "Wyświetl kategorie" "Dodaj słowo kluczowe do kategorii" "Usuń słowo kluczowe z kategorii" "Usuń kategorię")
flag="1"

while getopts ":hv" option;
do
	case $option in
		"h")
		flag="0"
		echo "Script does not support any parameters yet";;
		"v")
		flag="0"
		echo $version;;
	esac
done

sed -i '/^$/d' keyWordCategories.txt
readarray -t keyWordCategories < keyWordCategories.txt

ls /home > /tmp/allUsers.txt

printPrimaryMenu(){
	option=`zenity --list --column=Menu "${menu[@]}" --height 250 --width 400`
	case $option in
		"Generuj raport") generateReport;;
		"Dodaj słowa kluczowe") addKeyWord;;
		"Statystyki i monitoring") statistics;;
		"Ustawienia raportu") reportSettings;;
		*)
			if [[ -f /tmp/report.html ]]; then
				rm /tmp/report.html
			fi
			if [[ -f /tmp/data.dat ]]; then
				rm /tmp/data.dat
			fi
			if [[ -f /tmp/allUsers.txt ]]; then
				rm /tmp/allUsers.txt
			fi
		;;
	esac
}

generateReport(){
	./generateReport.sh
	firefox /tmp/report.html
	printPrimaryMenu
}

addKeyWord(){
	option=`zenity --list --column=Menu "${addKeyWordMenu[@]}" --height 300 --width 350`
	case $option in
		"Dodaj kategorię")
			value=`zenity --entry --text "Podaj nazwę nowej kategorii"`
			echo $value >> keyWordCategories.txt
			touch "keyWordCategories/${value}.txt"
			readarray -t keyWordCategories < keyWordCategories.txt
			addKeyWord
		;;
		"Wyświetl kategorie")
			value=`zenity --list --column=Kategorie "${keyWordCategories[@]}"`
			cat "keyWordCategories/${value}.txt" | zenity --text-info --height 700 --width 400 --title "Słowa kluczowe"
			addKeyWord	
		;;
		"Dodaj słowo kluczowe do kategorii")
			value=`zenity --list --column=Kategorie "${keyWordCategories[@]}"`
			word=`zenity --entry --text "Podaj słowo kluczowe"`
			echo $word >> "keyWordCategories/${value}.txt"
			addKeyWord
		;;
		"Usuń słowo kluczowe z kategorii")
			value=`zenity --list --column=Kategorie "${keyWordCategories[@]}"`
			readarray -t words < keyWordCategories/${value}.txt
			word=`zenity --list --column=Slowo "${words[@]}"`
			sed "/${word}/d" keyWordCategories/${value}.txt > temp.txt
			cat temp.txt > keyWordCategories/${value}.txt
			rm temp.txt
			addKeyWord
		 ;;
		"Usuń kategorię")
			value=`zenity --list --column=Kategorie "${keyWordCategories[@]}"`
			rm "keyWordCategories/${value}.txt"
			sed "/${value}/d" keyWordCategories.txt > temp.txt
			cat temp.txt > keyWordCategories.txt
			rm temp.txt
			readarray -t keyWordCategories < keyWordCategories.txt
			addKeyWord
		;;
		*) printPrimaryMenu
	esac
}

statistics(){
	./generateReport.sh
	dayRange=`cat config.txt | cut -d "," -f 1`
	totalKeyWords=0
	column=("Wartość")
	
	totalSearch=(`wc -l /tmp/data.dat | cut -d " " -f 1`)
	column+=("Ilość wyszukiwań")
	column+=($totalSearch)
	
	column+=("Ilość kategorii")
	column+=(`wc -l keyWordCategories.txt | cut -d " " -f 1`)
	
	column+=("Ilość słów kluczowych")
	readarray -t categories < keyWordCategories.txt
	for i in "${categories[@]}"
	do
		count=`wc -l keyWordCategories/$i.txt | cut -d " " -f 1`
		sum=$(($totalKeyWords + $count))
		totalKeyWords=$sum
	done
	column+=($totalKeyWords)
	
	totalKeyWordOccurs=`cat /tmp/keyWords.txt`
	column+=("Łącznie znalezionych słów kluczowych")
	column+=($totalKeyWordOccurs)
	
	column+=("Średnia ilość słów kluczowych na ilość wyszukań")
	value="0"`bc <<< "scale=3; $totalKeyWordOccurs/$totalSearch"`
	column+=($value)
	
	zenity --list --multiple --column=Nazwa --column="${column[@]}" --height 300 --width 500 
	rm /tmp/keyWords.txt
	printPrimaryMenu
}

reportSettings(){
	config=$(zenity --forms --title="Ustawienia raportu" \
	--separator="," \
	--add-entry="Zakres dni obejmujący raport" \
	--add-entry="Zapisz raport [T/N]" \
	--add-entry="Lokalizacja pliku raportu" \
	--add-entry="Uwzględniaj tylko słowa kluczowe [T/N]");
	echo $config > config.txt
	printPrimaryMenu
}

if [[ $flag == "1" ]]; then
	printPrimaryMenu
fi
