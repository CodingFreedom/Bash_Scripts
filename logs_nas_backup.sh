#!/bin/bash

if [ $# -ne 4 ];
then
    echo ""
    echo "Numero di parametri insufficiente!"
    echo ""
    echo "Parametri necessari:"
    echo ""
    echo "1 - Cartella contenente le applicazioni"
    echo "2 - Mount point per la cartella residente sul NAS (va creato nella cartella contenente le applicazioni)"
    echo "3 - Cartella contenente i LOG"
    echo "4 - Numero di giorni oltre i quali comprimere i LOG"
    echo ""
    echo "Sintassi di esempio:"
    echo ""
    echo "./logs_nas_backup.sh opt nas_backup log 7"
    echo ""
    echo "IMPORTANTE: Lo script replica su NAS, l'albero nativo delle cartelle."
    echo ""
else
    SOURCE_ROOT=$1
    BACKUP_FOLDER=$2
    LOG_FOLDER=$3
    NAS_PATH=$SOURCE_ROOT/$BACKUP_FOLDER/$SOURCE_ROOT
    SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    SCRIPTMAIL=$SCRIPTDIR/PythonSendEmail.sh
    LOGFILE="/tmp/execution_script.log"
    NOME_PROCEDURA="$HOSTNAME: Spostamento log compressi su NAS. Processo/Applicazione - "
    # Di seguito il controllo per l'esistenza della cartella NAS_PATH. Se non esiste, viene creata.
        if [ ! -d "$NAS_PATH" ];
        then
            mkdir -p $NAS_PATH
        fi
    # Di seguito viene impostato il file contenente l'elenco delle cartelle delle applicazioni
    LISTAPP=/$SOURCE_ROOT/listapp.txt
    # Di seguito viene controllata l'esistenza del file contenente l'elenco delle cartelle delle applicazioni e successivamente al suo esito positivo, prosegue l'esecuzione dello script
    if [ -f "$LISTAPP" ];
    then
        for i in $(cat $LISTAPP)
        do
            mupper="`echo $i | tr '[:lower:]' '[:upper:]'`"
            ESITO_PROCEDURA=": OK"
            cd /$SOURCE_ROOT/$i/$LOG_FOLDER/
                if [ $? -ne 0 ];
                then
                   ESITO_PROCEDURA=": KO"
                   MSG_BODY=$(echo "Accesso alla cartella di origine dei log /$SOURCE_ROOT/$i/$LOG_FOLDER su $HOSTNAME$ESITO_PROCEDURA. Controllare la situazione.")
                else
                find -maxdepth 1 -type f -mtime +$4 -exec gzip -9 {} \;
                    if [ $? -ne 0 ];
                    then
                       ESITO_PROCEDURA=": KO"
                       MSG_BODY=$(echo "Compressione dei log (>$4 gg) presenti nella cartella /$SOURCE_ROOT/$i/$LOG_FOLDER/ su $HOSTNAME$ESITO_PROCEDURA. Controllare la situazione.")
                    else
                    mv *.gz /$NAS_PATH/$i/$LOG_FOLDER/
                        if [ $? -ne 0 ];
                        then
                           ESITO_PROCEDURA=": KO"
                           MSG_BODY=$(echo "Spostamento dei log compressi nella cartella /$NAS_PATH/$i/$LOG_FOLDER su $HOSTNAME$ESITO_PROCEDURA. Controllare la situazione.")
                        else
                           MSG_BODY=$(echo "Spostamento dei log compressi nella cartella /$NAS_PATH/$i/$LOG_FOLDER su $HOSTNAME$ESITO_PROCEDURA")
                        fi
                    fi
                fi
            echo $NOME_PROCEDURA$mupper$ESITO_PROCEDURA > $LOGFILE
            echo $MSG_BODY >> $LOGFILE
            $SCRIPTMAIL
        done
    else
        NOME_PROCEDURA="$HOSTNAME: Spostamento log compressi su NAS. Esito - KO"
        MSG_BODY=$(echo "Procedura impossibile. File $LISTAPP mancante. Controllare la situazione.")
        echo $NOME_PROCEDURA > $LOGFILE
        echo $MSG_BODY >> $LOGFILE
        $SCRIPTMAIL
    fi
fi
