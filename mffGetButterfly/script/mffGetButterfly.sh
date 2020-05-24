#!/usr/bin/env bash
#
# Bestimmten Schmetterling mithilfe rotem Ei f�r bestimmten Slot kaufen
#
exec 2>&1
: ${1:?MFF Benutzername fehlt}
: ${2:?MFF Passwort fehlt}
: ${3:?MFF Server fehlt}
: ${4:?Schmetterlings-Nr. fehlt}

MFFUSER=$1
MFFPASS=$2
MFFSERVER=$3
BUTTERFLY=$4
SLOT1=$5
SLOT2=$6
SLOT3=$7
SLOT4=$8
SLOT5=$9
SLOT6=${10} # otherwise seen as $1 and an appended '0'
MAXREPEAT=25

JQBIN=$(which jq)
: ${JQBIN:?jq fehlt}
LOGFILE=/tmp/mffbutterfly$$.log
OUTFILE=/tmp/butterflytemp$$.html
COOKIEFILE=/tmp/butterflycook$$.txt
rm -f $COOKIEFILE 2>/dev/null
NANOVALUE=$(echo $(($(date +%s%N)/1000000)))
LOGOFFURL="http://s${MFFSERVER}.myfreefarm.de/main.php?page=logout&logoutbutton=1"
POSTURL="https://www.myfreefarm.de/ajax/createtoken2.php?n=${NANOVALUE}"
AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17.13 (KHTML, like Gecko) Chrome/57.0.2940.56 Safari/537.17.13"
POSTDATA="server=${MFFSERVER}&username=${MFFUSER}&password=${MFFPASS}&ref=&retid="
AJAXURL="http://s${MFFSERVER}.myfreefarm.de/ajax/"
aBUTTERFLIES='{"1":"Zitronenfalter","2":"Kleiner Fuchs","3":"Resedafalter","4":"Admiral","5":"C-Falter","6":"Baumwei�ling","7":"Schachbrett","8":"Argus Bl�uling","9":"Aurorafalter","10":"Tagpfauenauge","11":"Schwalbenschwanz","12":"Kr�he","13":"Monarch","14":"Zebrafalter","15":"Blauer Morpho","16":"Glasfl�gler","17":"G�tterbaum-Spinner","18":"Atlasspinner","19":"Kometen-Motte","20":"Kleiner Feuerfalter","21":"Sumpfwiesen-Perlmuttfalter","22":"Wei�dolch-Bl�uling","23":"Roter Apollo","24":"Goldener Scheckenfalter","25":"Gro�er Feuerfalter","26":"Gro�er Schillerfalter","27":"Schwarzer B�r","28":"Segelfalter","29":"Rotrandb�r","30":"Totenkopfschw�rmer","31":"Mittlerer Weinschw�rmer","32":"Brauner B�r","33":"Oleanderschw�rmer","34":"Hornissen-Glasfl�gler","35":"Taubenschw�nzchen"}'

function login-MFF {
 echo "Login-Token fuer MFF server ${MFFSERVER} anfordern..."
 MFFTOKEN=$(wget -v -o $LOGFILE -O - --user-agent="$AGENT" --post-data="$POSTDATA" --keep-session-cookies --save-cookies $COOKIEFILE "$POSTURL" | sed -e 's/\[1,"\(.*\)"\]/\1/g' | sed -e 's/\\//g')
 echo "Anmeldung an MFF Server ${MFFSERVER} mit Benutzername $MFFUSER"
 wget -v -o $LOGFILE --output-document=$OUTFILE --user-agent="$AGENT" --keep-session-cookies --save-cookies $COOKIEFILE "$MFFTOKEN"
 RID=$(grep -om1 '[a-z0-9]\{32\}' $OUTFILE)
 if [ -z "$RID" ]; then
  echo "FATAL: keine RID erhalten"
  # abmelden...
  wget -v -o $LOGFILE --output-document=/dev/null --user-agent="$AGENT" --load-cookies $COOKIEFILE "$LOGOFFURL"
  exit 1
 fi
 echo "Anmeldung erfolgreich"
}

function logout-MFF {
 echo "Abmelden..."
 wget -v -o $LOGFILE --output-document=/dev/null --user-agent="$AGENT" --load-cookies $COOKIEFILE "$LOGOFFURL"
 rm $LOGFILE $OUTFILE $COOKIEFILE
}

login-MFF

AJAXFARM="${AJAXURL}farm.php?rid=${RID}&"

function SendAJAXFarmRequest {
 local sAJAXSuffix=$1
 wget -nv -T10 -a $LOGFILE --output-document=$OUTFILE --user-agent="$AGENT" --load-cookies $COOKIEFILE ${AJAXFARM}${sAJAXSuffix}
}

function GetFarmData {
 wget -nv -T10 -a $LOGFILE --output-document=$OUTFILE --user-agent="$AGENT" --load-cookies $COOKIEFILE "${AJAXFARM}mode=getfarms&farm=1&position=0"
}

function getOut {
 logout-MFF
 echo "If you survive, please come again."
 exit 0
}

function check_SlotIsFree {
 # gibt 0 (true) zur�ck, wenn slot frei ist
 local sSlotType
 sSlotType=$($JQBIN -r '.updateblock.farmersmarket.butterfly.data.breed["'${SLOT}'"]? | type' $OUTFILE)
 if [ -z "$sSlotType" ] || [ "$sSlotType" = "null" ]; then
  return 0
 else
  return 1
 fi
}

function check_IsItTheOne {
 # gibt 0 (true) zur�ck, wenn gew�nschter schmetterling gekauft wurde
 # oder ein unbrauchbarer wert zur�ckkommt
 local iButterfly
 local sButterfly
 iButterfly=$($JQBIN -r '.updateblock.farmersmarket.butterfly.data.breed["'${SLOT}'"]?.butterfly?' $OUTFILE)
 sButterfly=$(echo $aBUTTERFLIES | $JQBIN -r '.["'${iButterfly}'"]')
 if [ "$iButterfly" = "null" ]; then
  echo "Fehler beim Lesen des Slots ${SLOT}!"
  return 0
 fi
 if [ $iButterfly -eq $BUTTERFLY ]; then
  echo "Ein ${sButterfly} Ei liegt nun im Slot ${SLOT}"
  return 0
 else
  echo -n "${sButterfly}...ist unerw�nscht."
  return 1
 fi
}

function getDeco {
 local iButterfly=$($JQBIN -r '.updateblock.farmersmarket.butterfly.data.breed["'${SLOT}'"]?.butterfly?' $OUTFILE)
 if [ "$iButterfly" = "null" ]; then
  # return if there's been an error
  return 0
 fi
 local bQuestIsString=$($JQBIN '.updateblock.farmersmarket.butterfly.data.last_questid? | type == "string"' $OUTFILE)
 if [ "$bQuestIsString" = "false" ]; then
  echo "Wert der letzten Quest kann nicht gelesen werden. Dekokauf nicht m�glich."
  return
 fi
 local iQuest=$($JQBIN -r '.updateblock.farmersmarket.butterfly.data.last_questid?' $OUTFILE)
 if [ $iQuest -lt 1 ]; then
  echo "Du kannst (noch) keinerlei Deko kaufen."
  return
 fi
 if [ $BUTTERFLY -ge 12 ] && [ $BUTTERFLY -le 19 ]; then
  # Schmetterling ist tropisch
  if [ $iQuest -ge 35 ]; then
   echo "Dschungel-Gurke kaufen..."
   SendAJAXFarmRequest "slot=${SLOT}&id=6&mode=butterfly_shopbuy"
   return
  else
   echo "Du kannst die Dschungel-Gurke (noch) nicht kaufen."
  fi
 fi
 echo "Brennessel kaufen..."
 SendAJAXFarmRequest "slot=${SLOT}&id=1&mode=butterfly_shopbuy"
}

trap getOut SIGINT SIGTERM ERR

GetFarmData
echo -n "Gekauft werden soll: Ei #${BUTTERFLY} - "
echo $aBUTTERFLIES | $JQBIN -r '.["'${BUTTERFLY}'"]'
for SLOT in $SLOT1 $SLOT2 $SLOT3 $SLOT4 $SLOT5 $SLOT6; do
 while (true); do
  if [ $MAXREPEAT -eq 0 ]; then
   echo "Maximale Kauf-Versuche erreicht!"
   # getOut
   break
  fi
  if ! check_SlotIsFree; then
   echo "Slot $SLOT ist besetzt."
   # getOut
   break
  fi
  echo "Ei f�r Slot $SLOT kaufen ... Versuche �brig: $MAXREPEAT"
  SendAJAXFarmRequest "slot=${SLOT}&id=2&mode=butterfly_startbreed"
  if check_IsItTheOne; then
   sleep 1
   getDeco
   # getOut
   break
  fi
  echo " Ei entfernen..."
  sleep 1
  SendAJAXFarmRequest "slot=${SLOT}&mode=butterfly_delete"
  MAXREPEAT=$((MAXREPEAT - 1))
  sleep 1
 done
MAXREPEAT=25
done

getOut
