#!/bin/bash

MYSQL_BIN="/proj/svr/mysql/bin/mysql"
user=xtrbackup
password='To3ru7Z*%ebra6'
PORT=3306
filedir="/proj/logs/deadlock_file"
instance=buffalo
instance_bi=moose

New_deadlock() {

    new_line_tile=$(grep -n "LATEST DETECTED DEADLOCK" $1 | cut -d ':' -f 1)
    new_line_time=$(echo "$new_line_tile + 2" | bc)
    last_dect_time="$(head -n $new_line_time $1 | tail -n 1)" ###截取死锁发生的时间戳
                                            
    #[ -e $2 ] || cp $1 $2 #拿这次输出信息，和上次输出信息对比；如果是第一次检测，将这次输出信息cp作为上次输出信息
     
                                         
    #old_line_tile=$(grep -n "LATEST DETECTED DEADLOCK" $2 | cut -d ':' -f 1)
                                         
    if [ ! -e $2 ];then
      echo 1
      mv $1  $2  ##判断上次输出是否为死锁，不是的话，直接返回1 表明最近一次是新的死锁。并将此次输出信息重命名
      exit 1
    else      ##否则对比两次的时间戳
      old_line_tile=$(grep -n "LATEST DETECTED DEADLOCK" $2 | cut -d ':' -f 1)
      old_line_time=$(echo "$old_line_tile + 2" | bc)
      old_last_dect_time="$(head -n $old_line_time  $2 | tail -n 1)"
      mv $1  $2 #输出信息为下一次检测做准备
                                         
      if [ "$last_dect_time" = "$old_last_dect_time" ];then
        echo 0
      else
        cp $2 $1_detail #已判定为死锁，需要保留作案信息
        echo 1
      fi
  fi
}
deadlock_check() {
    $MYSQL_BIN -u $user -p$password -h 172.17.2.78  -P$PORT -e "show engine innodb status\G" > ${filedir}/innodb_status_buffalo_new
    have_dead_lock=$(grep -c  "LATEST DETECTED DEADLOCK" ${filedir}/innodb_status_buffalo_new)

    have_new_lock=0
    #判断这次检测是否包含死锁信息，包含的话 让 New_dead_lock 做死锁对比否则 返回0
    if [ $have_dead_lock -gt 0 ];then

      have_new_lock=`New_deadlock ${filedir}/innodb_status_buffalo_new ${filedir}/innodb_status_buffalo_old`

    else
      echo 0
    fi
   
    if [ ${have_new_lock} -eq 1 ];then
       echo "have deadlock found!!!"
       sed  -n "/LATEST DETECTED DEADLOCK/,/WE ROLL BACK TRANSACTION/p" ${filedir}/innodb_status_buffalo_old > ${filedir}/have_buffalo_new_lock.txt
       cat ${filedir}/have_buffalo_new_lock.txt |mail -s "${instance} 实例发生死锁，请关注!!!" yihk@yyft.com
    else
      echo "not deadlock found!!!"
    fi
    
}

deadlock_check_bi() {
    $MYSQL_BIN -u $user -p$password -h 172.17.2.79  -P$PORT -e "show engine innodb status\G" > ${filedir}/innodb_status_moose_new
    have_dead_lock=$(grep -c  "LATEST DETECTED DEADLOCK" ${filedir}/innodb_status_moose_new)
    have_new_lock=0
    #判断这次检测是否包含死锁信息，包含的话 让 New_dead_lock 做死锁对比否则 返回0
    if [ $have_dead_lock -gt 0 ];then
      have_new_lock=`New_deadlock ${filedir}/innodb_status_moose_new ${filedir}/innodb_status_moose_old`
    else
      echo 0
    fi
   
    if [ ${have_new_lock} -eq 1 ];then
       echo "have deadlock found!!!"
       sed  -n "/LATEST DETECTED DEADLOCK/,/WE ROLL BACK TRANSACTION/p" ${filedir}/innodb_status_moose_old > ${filedir}/have_moose_new_lock.txt
       cat ${filedir}/have_moose_new_lock.txt |mail -s "${instance_bi} 实例发生死锁，请关注!!!" yihk@yyft.com,bi@yyft.com
    else
      echo "not deadlock found!!!"
    fi
    
}

deadlock_check
deadlock_check_bi

