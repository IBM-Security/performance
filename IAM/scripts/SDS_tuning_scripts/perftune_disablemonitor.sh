#!/bin/sh
#    This turns monitoring on at the database manager level:
db2 update database manager configuration using DFT_MON_STMT OFF
db2 update database manager configuration using DFT_MON_BUFPOOL OFF
db2 update database manager configuration using DFT_MON_LOCK OFF
db2 update database manager configuration using DFT_MON_SORT OFF
db2 update database manager configuration using DFT_MON_UOW OFF
db2 update database manager configuration using DFT_MON_TABLE OFF
#    Then restart your database:
#db2stop
#db2start