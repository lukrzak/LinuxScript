#!/bin/bash

#config options read
dayRange=`cat config.txt | cut -d "," -f 1`
saveReport=`cat config.txt | cut -d "," -f 2`
localisation=`cat config.txt | cut -d "," -f 3`
onlyKeyWords=`cat config.txt | cut -d "," -f 4`

#DB querry to get search history
val=`fuser ~/.mozilla/firefox/sibjlrwt.default-release/places.sqlite | cut -d " " -f 2`
if [[ $val -gt 1 ]]; then
	kill -9 $val
fi
readarray -t users < /tmp/allUsers.txt
echo "" > /tmp/data.dat

for i in "${users[@]}"
do
	echo "" >> /tmp/data.dat
	echo "użytkownik: $i --------------------------" >> /tmp/data.dat
	dbDirectory=`find /home/$i/.mozilla/firefox -maxdepth 1 | grep "release" | cut -d "/" -f 6`
	sqlite3 /home/$i/.mozilla/firefox/$dbDirectory/places.sqlite "SELECT datetime(last_visit_date/1000000, 'unixepoch') AS last_visit_date, url, visit_count FROM moz_places WHERE last_visit_date > 1;" >> /tmp/data.dat
done

#Getsonly search history in day range 
readarray -t data < /tmp/data.dat
for i in "${data[@]}"
do
	dat=`echo $i | cut -d " " -f 1 | tr '-' ' ' | tr -d [":space:"]`
	actualDate=$(date +'%Y%m%d')
	if [[ $dat != "użytkownik:" && ! -z $dat ]]; then
		let dif=(`date +%s -d $actualDate`-`date +%s -d $dat`)/86400
	fi
	if [[ $dif -le $dayRange || $dat == "użytkownik:" ]]; then
		echo $i >> /tmp/temp.txt
	fi
done
cat /tmp/temp.txt > /tmp/data.dat

#Finds key words
readarray -t keyWordCategories < keyWordCategories.txt
echo "" > /tmp/temp.txt
for i in "${keyWordCategories[@]}"
do
	total=0
	readarray -t keyWords < keyWordCategories/$i.txt
	for j in "${keyWords[@]}"
	do
		count=`grep -c $j /tmp/data.dat`
		sum=$(($total + $count))
		total=$sum
	done
	echo "$i $total" >> /tmp/temp.txt
done

#Generates pie chart
gnuplot <<'END_GNUPLOT'
stats '/tmp/temp.txt' u 2 noout
ang(x)=x*360.0/STATS_sum
perc(x)=x*100.0/STATS_sum

set size square
set xrange[-1:1.5]
set yrange[-1.25:1.25]
set style fill solid 1

unset border
unset tics
unset key

Ai = 0.0; Bi = 0.0;
mid = 0.0;
i = 0; j = 0;
yi = 0.0; yi2 = 0.0;

set output '/tmp/report.html'
set terminal canvas
set title "Wykres ilosci wyszukanych slow wedlug kategorii"

plot 	'/tmp/temp.txt' u (0):(0):(1):(Ai):(Ai=Ai+ang($2)):(i=i+1) with circle linecolor var,\
	'/tmp/temp.txt' u (1.5):(yi=yi+0.5/STATS_records):($1) w labels, \
	'/tmp/temp.txt' u (1.3):(yi2=yi2+0.5/STATS_records):(j=j+1) w p pt 5 ps 2 linecolor var,\
	'/tmp/temp.txt' u (mid=Bi+ang($2)*pi/360, Bi=2.0*mid-Bi, 0.5*cos(mid)):(0.5*sin(mid)):(sprintf('%.0f (%.1f\%)', $2, perc($2))) w labels

END_GNUPLOT

#prepares .html file to be extended
sed "/<\/html>/d" /tmp/report.html > /tmp/temp.txt
sed "/<\/body>/d" /tmp/temp.txt > /tmp/temp2.txt

#adds search log to report.html
keyWordsArray=()
for i in "${keyWordCategories[@]}"
do
	readarray -t keyWords < keyWordCategories/$i.txt
	for j in "${keyWords[@]}"
	do
		keyWordsArray+=("$j")
	done
done

totalKeyWordOccurs=0
readarray -t data < /tmp/data.dat
for i in "${data[@]}"
do
	hasKeyWord=0
	for j in "${keyWordsArray[@]}"
	do	
		if [[ "$i" == *"$j"* ]]; then
			hasKeyWord=1
		fi
	done
	if [[ hasKeyWord -eq 1 ]]; then
		increment=$(($totalKeyWordOccurs + 1))
		totalKeyWordOccurs=$increment
	fi
	
	line=`echo $i | cut -d "|" -f 1,2 | tr "|" " "`
	if [[ hasKeyWord -eq 0 && $onlyKeyWords == "N" ]]; then
		echo "<p>$line</p>" >> /tmp/temp2.txt
	elif [[ $i == "użytkownik:"* ]]; then
		echo "<p>$line</p>" >> /tmp/temp2.txt
	elif [[ hasKeyWord -eq 1 && $onlyKeyWords == "T" ]]; then
		echo "<p>$line</p>" >> /tmp/temp2.txt
	elif [[ $onlyKeyWords == "N" ]]; then
		echo "<p style='color:red'>$line</p>" >> /tmp/temp2.txt
	fi
done
echo $totalKeyWordOccurs > /tmp/keyWords.txt

#generates final report and cleans temporary files
echo "</body>" >> /tmp/temp2.txt
echo "</html>" >> /tmp/temp2.txt
cat /tmp/temp2.txt > /tmp/report.html
if [[ $saveReport == "T" ]]; then
	dat=$(date +'%Y-%m-%d')
	cat /tmp/temp2.txt > $localisation/$dat.html
fi
rm /tmp/temp.txt
rm /tmp/temp2.txt
