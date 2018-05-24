#!/bin/bash

###### set path to staged CRLs
root_path=$(dirname `which $0`)/
crl_path=$root_path/crl/

###### set client SSL profile name
#clientssl_prof=test-sslcrof
crl_object=crl_object.crl

###### set INI file path
crl_ini=$root_path/crlupdate.ini



###### CRL is updated 6 days before end validity (864000 seconds = 6 days)
crl_threshold=864000
###### FUNCTIONS ######
GET_CURRENT_CRL() {
   remote_path=$1
   remote_name=$2
   ## get the current CRL (or retrieve if missing)
   if [ ! -f $crl_path$remote_name ]
   then
      [ -d $crl_path ] || mkdir $crl_path
      ## file does not exist - go get it
      logger -p local0.info -t CRLUPDATE "Error: File ($crl_path$remote_name) doesn't exist - attempting to retrieve it"
      ret=`curl --url $remote_path$remote_name --remote-name --silent --write-out "%{http_code}"`
      if [ $ret -eq 200 ] && [ -f $remote_name ]
      then
         ## got a new CRL (and we know/assume it's current)
         mv $remote_name $crl_path
         ## convert a copy to PEM format
         openssl crl -in $crl_path$remote_name -inform DER -outform PEM -out $crl_path$remote_name.PEM
         HAS_UPDATED=1
         return 0
      else
         ## didn't get CRL - error and log
         rm -f $remote_name
         logger -p local0.info -t CRLUPDATE "Error: Could not retrieve CRL ($remote_name) from ($remote_path)"
         return 1
      fi
   else
      ## already have the CRL - now check to see if it's valid

      ## get the current date
      this_date=`date +%s`

      ## extract the date from the current CRL
      this_crl_date_literal=`openssl crl -in $crl_path$remote_name -inform DER -noout -nextupdate |sed s/nextUpdate=//`
      this_crl_date=`date -d "$this_crl_date_literal" +%s`

      ## compare current date and current CRL date for threshold
      if [ $this_date -ge $(($this_crl_date - $crl_threshold)) ]
      then
         ## crl date exceeds threshold - crl is about to expire or has expired - fetch the new crl
         logger -p local0.info -t CRLUPDATE "Error: $remote_name CRL exceeds the threshold (is expired or about to expire)"
         ret=`curl --url $remote_path$remote_name --remote-name --silent --write-out "%{http_code}"`
         if [ $ret -eq 200 ] && [ -f $remote_name ]
         then
            ## got a new CRL (and we know/assume its current)
            mv $remote_name $crl_path
            ## convert a copy to PEM format
            openssl crl -in $crl_path$remote_name -inform DER -outform PEM -out $crl_path$remote_name.PEM
            HAS_UPDATED=1
            return 0
         else
            ## didn't get CRL - error and log
            rm -f $remote_name
            logger -p local0.info -t CRLUPDATE "Error: Could not retrieve CRL ($remote_name) from ($remote_path)"
            return 1
         fi
      else
         ## CRL is current
         return 0
      fi
   fi
}
###### END FUNCTIONS ######

HAS_UPDATED=0

## loop through CRL ini file to retrieve listed CRLs
while read p
do
   file=${p##*/}
   path=`echo $p |sed s/$file//`
   GET_CURRENT_CRL $path $file
done < $crl_ini

if [ $HAS_UPDATED == 1 ]
then
   ## only proceed if some CRLs have been updated
   logger -p local0.info -t CRLUPDATE "Some CRLs have been updated - push to client SSL profile"

   ## delete existing crl concat files in path
   rm -f $crl_path/crl.*

   ## concat the existing PEM CRLs
   this_date=`date +%s`
   big_crl=$root_path\crl.$this_date
        logger -p local0.info -t CRLUPDATE "concat $big_crl"
   for f in $crl_path*.PEM
   do
      echo "### $f" >>$big_crl
      cat $f >>$big_crl
   done
   # install the new on CRL to the system
   tmsh modify sys file ssl-crl $crl_object source-path file:$big_crl
   rm -f $big_crl

else
   ## no CRL has been updated
   logger -p local0.info -t CRLUPDATE "All CRLs are up to date"
fi
