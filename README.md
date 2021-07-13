# wb38-backups
> Pregunta 1 : configura el programa rsnapshot para que haga backups del propio servidor de backups. Podemos hacer backup de root y etc y así tendremos todas las configuraciones backupeadas. Cuando lo tengas puedes probar que funciona ejecutando /usr/bin/rsnapshot -c /etc/rsnapshot.conf daily varias veces.

Hemos usado esta config:
```
config_version	1.2
snapshot_root	/var/cache/rsnapshot/
cmd_cp		/bin/cp
cmd_rm		/bin/rm
cmd_rsync	/usr/bin/rsync
cmd_logger	/usr/bin/logger
retain	daily	7
retain	weekly	4
retain	monthly	12
verbose		2
loglevel	3
lockfile	/var/run/rsnapshot.pid
backup	/etc/		localhost/
backup	/root/		localhost/
```

Con cada ejecución nos crea un fichero daily.NUM

> Pregunta 2 : crea un directorio en /etc/rsnapshot.d. Crea un script de bash que tome como parámetro $1 tres posibles opciones ( daily, weekly, monthly) y con todas las configuraciones *.conf contenidas en el directorio que acabas de crear, ejecute el backup que especifiquemos. Idealmente el script hará un echo antes de hacer cada backup, con la configuración que va a realizar de backup. Cuando lo tengas funcionando cambia el cron original para que ejecute nuestro wrapper :
```
#!/bin/bash

FREQ=$1
BKCMD="/usr/bin/rsnapshot -c "
CONFDIR="/etc/rsnapshot.d"


for C in `ls $CONFDIR/*.conf`; do
    echo "Realizando backup de $C con la siguiente configuración:"
    grep -v "^#" $C | grep ^[a-zA-Z] 
    $BKCMD $C $FREQ
done
```
> Pregunta 3 : crea ahora una nueva configuración para realizar backups de la máquina de wordpress. Idealmente añadiremos los paths home y donde se encuentre la web al backup. Añade también un backup script de mysql. Cuando lo tengas todo prueba que todo funciona correctamente.
 Creamos una llave ssh y copiamos la pública en nuestro server de wordpress (trouble.devops-alumno08.com) en los authorized_keys de root:

```ssh-keygen -t rsa -b 4096```
	
 Para que pueda funcionar en el cron que hemos definido hay que crear la config de ssh de root con lo siguiente:

```
Host trouble.devops-alumno08.com
 HostName trouble.devops-alumno08.com
 User root
 IdentityFile .ssh/id_rsa
```

Creamos el fichero con la nueva config en la carpeta de /etc/rsnapshot.d/ para nuestro server de wordpress:
```
config_version	1.2
snapshot_root	/var/cache/rsnapshot/trouble.devops-alumno08.com
cmd_cp		/bin/cp
cmd_rm		/bin/rm
cmd_rsync	/usr/bin/rsync
cmd_ssh		/usr/bin/ssh
cmd_logger	/usr/bin/logger
retain	daily	7
retain	weekly	4
retain	monthly	12
verbose		2
loglevel	3
lockfile	/var/run/rsnapshot.pid
backup	root@trouble.devops-alumno08.com:/var/www/wordpress/		./
backup	root@trouble.devops-alumno08.com:/etc/		./
backup	root@trouble.devops-alumno08.com:/home/		./
backup_exec	ssh root@trouble.devops-alumno08.com "mysqldump --defaults-file=/etc/mysql/debian.cnf --single-transaction --quick --all-databases | bzip2 -c > /var/db/dump/trouble-$(date +%Y%m%d-%H%M%S).sql.bz2"
backup	root@trouble.devops-alumno08.com:/var/db/dump/	./
```

> Pregunta 4 : Mira como puedes hacer que el cron te envie un correo con el contenido de la ejecución del backup. Como nuestro wrapper hace echo de cada config antes de hacer el backup, cuando lo tengamos si esta todo bien recibiremos un correo tipo así:
Instalamos mailutils
```apt install mailutils```

Y cambiamos el script para el envío de fallos por mail:
```
#!/bin/bash

FREQ=$1
BKCMD="/usr/bin/rsnapshot -c "
CONFDIR="/etc/rsnapshot.d"
REVMAIL="enrique.sanz@secuoyas.com"
ERRFILE="error.log"

for C in `ls $CONFDIR/*.conf`; do
    echo "Realizando backup de $C con la siguiente configuración:" | tee $ERRFILE
    grep -v "^#" $C | grep ^[a-zA-Z] | tee -a $ERRFILE
    $BKCMD $C $FREQ 2>&1 | tee -a $ERRFILE
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Hubo un error al crear el backup de $C"
        mail -s "Rsnapshot report" $REVMAIL < $ERRFILE
    fi
    rm $ERRFILE
done
```
> Pregunta 5 : Aprovisiona un nuevo servidor debian y restaura todo el servidor de wordpress a partir del backup y comprueba que todo funciona. Debes restaurar todo del backup, no vale hacer trampa. Si nos hemos dejado algun backup lo añadiremos a la config.
Copiamos de nuevo la clave pública que hemos creado anteriormente en los authorized_keys del nuevo servidor y para restaurar lanzamos los siguientes comandos.
```
SNAPPATH="/var/cache/rsnapshot/trouble.devops-alumno08.com/daily.0"
SNAPSRV="root@trouble.devops-alumno08.com"
LASTDUMP="trouble-20210712-220234.sql"
rsync -vart $SNAPPATH/var/www/wordpress $SNAPSRV:/var/www/wordpress
rsync -vart $SNAPPATH/etc $SNAPSRV:/etc
rsync -vart $SNAPPATH/var/db/dump/ $SNAPSRV:/var/db/dump/
ssh $SNAPSRV bzip2 -d /var/db/dump/${LASTDUMP}.bz2
ssh $SNAPSRV "mysql --one-database wordpress < /var/db/dump/${LASTDUMP}"
ssh $SNAPSRV service mysqld restart
ssh $SNAPSRV service php-fpm restart
ssh $SNAPSRV service apache2 restart
```
> Pregunta 6 : Crea una configuración nueva para realizar backups del servidor de elasticsearch que estamos usando en performance. Esta configuración lanzará un pre backup script que se conectará al servidor de ES y parará el demonio. Cuando termine lanzará un post backup script que lo volverá a encender. En los paths a realizar backup incorporaremos /var/lib/elasticsearch. Prueba que el backup funciona como esperas.
Copiamos la llave pública en el server de ELK y creamos el fichero elk.devops-alumno08.com
```
config_version	1.2
snapshot_root	/var/cache/rsnapshot/elk.devops-alumno08.com
cmd_cp		/bin/cp
cmd_rm		/bin/rm
cmd_rsync	/usr/bin/rsync
cmd_ssh		/usr/bin/ssh
cmd_logger	/usr/bin/logger
retain	daily	7
retain	weekly	4
retain	monthly	12
verbose		2
loglevel	3
lockfile	/var/run/rsnapshot.pid
cmd_preexec	ssh root@elk.devops-alumno08.com service kibana stop
cmd_postexec    ssh root@elk.devops-alumno08.com service kibana start
backup		root@elk.devops-alumno08.com:/var/lib/elasticsearch		./
backup		root@elk.devops-alumno08.com:/home/		./
```

> Pregunta 7 : Restaura el backup del elasticsearch en otro nodo y comprueba que no se ha perdido ningún documento.
Creamos el nuevo server a partir del snapshot y copiamos la llave pública
Restauramos los datos con:
```
ssh root@elk2.devops-alumno08.com service kibana stop
rsync -vart /var/cache/rsnapshot/elk2.devops-alumno08.com/daily.0/var/lib/elasticsearch root@elk2.devops-alumno08.com:/var/lib/elasticsearch
ssh root@elk2.devops-alumno08.com service kibana start
```

