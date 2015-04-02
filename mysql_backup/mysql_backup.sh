#!/bin/bash

decoder () {
    echo $1 | base64 --decode
}

export BACKUP_PATH="/mysql_backup"
export NAS_PATH="/nas_backup/mysql_backup"
# I valori per le credenziali di accesso devono essere inseriti nel loro valore codificato in base64
export UTENTE_DB=""
export PASSWORD_DB=""
export DATE="`date +"%Y%m%d"`"
export MYSQL="/usr/bin/mysql"
export MYSQLDUMP="/usr/bin/mysqldump"
export SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export SCRIPTMAIL=$SCRIPTDIR/PythonSendEmail.sh
export LOGFILE="/tmp/execution_script.log"

echo "* Inizio procedura mySQL_backup (singolo file per ogni database)"
echo "----------------------"
cd $BACKUP_PATH/
echo "* Creo il nuovo Backup."
$MYSQL -u $(decoder $UTENTE_DB) -p$(decoder $PASSWORD_DB) -Bse 'show databases' | grep -v 'information_schema\|performance_schema\|test\|mysql' |
while read m
do

export esito_backup=" Esito: OK"
export esito_compressione="(Compressione: OK)"
export esito_mantenimento_retention="(Retention: OK)"
export esito_spostamento_nas="(Spostamento su NAS: OK)"

$MYSQLDUMP -u $(decoder $UTENTE_DB) -p$(decoder $PASSWORD_DB) --single-transaction $(echo $m) > $(echo $m)_$DATE.sql
if [ $? -ne 0 ];
        then
                export esito_backup=" Esito: KO"
                export esito_compressione="(Compressione: NP)"
                export esito_mantenimento_retention="(Retention: NP)"
                export esito_spostamento_nas="(Spostamento su NAS: NP)"
                export mupper="`echo $m | tr '[:lower:]' '[:upper:]'`"
        else
                sleep 15m
                nice -n 20 gzip -9 $(echo $m)_$DATE.sql
                if [ $? -ne 0 ];
                        then
                                export mupper="`echo $m | tr '[:lower:]' '[:upper:]'`"
                                export esito_compressione="(Compressione: KO)"
                                                                        mv $(echo $m)_$DATE.sql $NAS_PATH
                                                                                if [ $? -ne 0 ];
                                                                                        then
                                                                                                export esito_spostamento_nas="(Spostamento su NAS: KO)"
                                                                                        fi
                        else
                                export mupper="`echo $m | tr '[:lower:]' '[:upper:]'`"
                                export totalfiledeleted="Totale file cancellati: `find $NAS_PATH -type f -name "$(echo $m)*" -mtime +30 | wc -l`"
                                find $NAS_PATH -type f -name "$(echo $m)*" -mtime +30 -exec rm -f {} \;
                                if [ $? -ne 0 ];
                                        then
                                                export esito_mantenimento_retention="(Retention: KO)"
                                        else
                                                mv $(echo $m)_$DATE.sql.gz $NAS_PATH
                                                if [ $? -ne 0 ];
                                                        then
                                                                export esito_spostamento_nas="(Spostamento su NAS: KO)"
                                                        fi
                                        fi
                fi
fi

echo "Backup MySQL DB" $mupper " - " $esito_backup " - " $esito_compressione " - " $esito_mantenimento_retention " - " $esito_spostamento_nas > $LOGFILE
echo "Procedura di Backup del DB" $mupper "Completata -" $esito_compressione  " - " $esito_mantenimento_retention " - " $totalfiledeleted " - " $esito_spostamento_nas >> $LOGFILE

$SCRIPTMAIL

done

echo "----------------------"
echo "Fatto"
exit 0