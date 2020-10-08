#!/bin/bash
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASS:=$MYSQL_PASSWORD}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }
[ -z "${GZIP_LEVEL}" ] && { GZIP_LEVEL=6; }
[[ ! "$SEGMENT_DB_TABLES" -eq "0" ]] && { ONLY_SCHEMA="--no-data"; }

DATE=$(date +%Y%m%d%H%M)
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"
DATABASES=${MYSQL_DATABASE:-${MYSQL_DB:-$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)}}
DB_COUNTER=0

backup_db () {
  DB_NAME=$1
  FILENAME=/backup/$DB_NAME.sql
  LATEST=/backup/latest.$DB_NAME.sql.gz
  if mysqldump --no-tablespaces $ONLY_SCHEMA -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" $DB_NAME $MYSQLDUMP_OPTS > "$FILENAME"
  then
    # Prettify SQL 
    cli-sql-formatter -f $FILENAME -o $FILENAME

    if [[ ! "$SEGMENT_DB_TABLES" -eq "0" ]]
    then
      for TABLE_NAME in `mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -B -e "show tables from $DB_NAME"`;
      do
          echo "Backing up table: "$TABLE_NAME""
          FILENAME=/backup/$DB_NAME.$TABLE_NAME.sql
          mysqldump --no-tablespaces --no-create-info -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" $DB_NAME $TABLE_NAME > $FILENAME
          cli-sql-formatter -f $FILENAME -o $FILENAME
      done;
    fi
    DB_COUNTER=$(( DB_COUNTER + 1 ))
  else
    rm -rf "$FILENAME"
  fi
}

can_backup_db () {
  # Databases starting with _ or with the following names won't be backed up
  [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]]
}


for db in ${DATABASES}
do
  if can_backup_db
  then
    echo "==> Dumping database: $db"
    backup_db "$db"
  fi
done

echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
