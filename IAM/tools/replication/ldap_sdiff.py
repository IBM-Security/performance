import ibm_db
import argparse
import sys
import csv
from datetime import datetime
import logging.config
import logging

logger = logging.getLogger(__name__)


def list_repl_contexts(conn, schema):
    """
    Execute SQL statement to return all DNs and ModifyTimestamps in order of DN
    from a LDAP Server.

    :param conn:
    :param schema:
    :return:
    """
    sql = (
        "select dn, dn_trunc, modify_timestamp - current timezone"  # Return timestamp in UTC format
        " from {}.ldap_entry"
        " order by dn_trunc"
    ).format(schema)
    logger.debug("Executing SQL: {}".format(sql))
    return ibm_db.exec_immediate(conn, sql)


def write_to_csv(writer, dn, dn2, dn_trunc, current_timestamp, modify_timestamp1, modify_timestamp2, status):
    """
    Write to CSV with additional checks to detect truncation issue and/or changes in flight.

    :param writer:
    :param dn:
    :param dn2:
    :param dn_trunc:
    :param current_timestamp:
    :param modify_timestamp1:
    :param modify_timestamp2:
    :param status:
    :return:
    """
    if modify_timestamp1 and modify_timestamp1 > current_timestamp:
        logger.debug("modify_timestamp1 > current_timestamp: {} > {}".format(modify_timestamp1, current_timestamp))
        status += '*'
    if modify_timestamp2 and modify_timestamp2 > current_timestamp:
        logger.debug("modify_timestamp2 > current_timestamp: {} > {}".format(modify_timestamp2, current_timestamp))
        status += '*'
    if dn != dn_trunc:
        logger.debug("DN Truncated: \n  DN - {}, \n  DN_TRUNC - {}".format(dn, dn_trunc))
        status += '#'
    if dn2 and dn != dn2:
        logger.debug("dn != dn2, dn:{} dn2{}".format(dn, dn2))
        status += '#'
    writer.writerow({
        'dn': dn,
        'modifyTimestamp1': modify_timestamp1,
        'modifyTimestamp2': modify_timestamp2,
        'status': status
    })


def print_legend(hostname1, hostname2):
    """
    Print a legend describing what the CSV output looks like.

    :param hostname1:
    :param hostname2:
    :return:
    """
    print("Legend for output:")
    print("  dn - distinguished name of the object that is out of sync or missing.")
    print("  modifyTimestamp1 - dn's object last modified on server: {}.".format(hostname1))
    print("  modifyTimestamp2 - dn's object last modified on server: {}.".format(hostname2))
    print("  status - the following are what the values mean:")
    print("    1: Object detected in both servers but modify timestamps are different indicating mis-match.")
    print("    2: Object found in {} but missing in {}.".format(hostname1, hostname2))
    print("    3: Object found in {} but missing in {}.".format(hostname2, hostname1))
    print("    #: Detecting truncation of DN, further comparison of object recommended.")
    print("    *: Detecting Modify Timestamp more recent than when this script started execution,")
    print("       further comparison of object recommended (replication may fix mis-match).")
    print("")
    print("Note: Timestamps are provided in UTC timezone.")
    print("")


def compare_all_entry_modify_timestamps(hostname1, conn1, schema1, hostname2, conn2, schema2, fout):
    """
    Compare all DNs from one LDAP server with another and print discrepancies.

    Note: dn_trunc is being used for checking discrepancies for highest efficiencies, however
    dn is bring printed in the output csv. There is a small chance that dn_trunc is truncated.

    :param conn1:
    :param conn2:
    :param schema1:
    :param schema2:
    :return:
    """
    current_timestamp = datetime.utcnow()
    count1, count2 = 0, 0
    # Get DNs from first server
    stmt1 = list_repl_contexts(conn1, schema1)
    result1 = ibm_db.fetch_tuple(stmt1)
    if not result1:
        raise Exception("No rows returned for {} server!".format(hostname1))
    # Get DNs from second server
    stmt2 = list_repl_contexts(conn2, schema2)
    result2 = ibm_db.fetch_tuple(stmt2)
    if not result2:
        raise Exception("No rows returned for {} server!".format(hostname2))
    # Compare all DNs from first and second server
    writer = csv.DictWriter(fout, ['dn', 'modifyTimestamp1', 'modifyTimestamp2', 'status'])
    writer.writeheader()
    while result1 and result2:
        dn1, dn_trunc1, modify_timestamp1 = result1[0].strip(), result1[1], result1[2]
        dn2, dn_trunc2, modify_timestamp2 = result2[0].strip(), result2[1], result2[2]
        count1 += 1
        count2 += 1
        if dn_trunc1 == dn_trunc2:
            if modify_timestamp1 != modify_timestamp2:
                # dn2 and dn2 should be same
                write_to_csv(writer, dn1, dn2, dn_trunc1, current_timestamp, modify_timestamp1, modify_timestamp2, '1')
            result1 = ibm_db.fetch_tuple(stmt1)
            result2 = ibm_db.fetch_tuple(stmt2)
        elif dn_trunc1 < dn_trunc2:
            write_to_csv(writer, dn1, None, dn_trunc1, current_timestamp, modify_timestamp1, None, '2')
            result1 = ibm_db.fetch_tuple(stmt1)
        else:
            write_to_csv(writer, dn2, None, dn_trunc2, current_timestamp, None, modify_timestamp2, '3')
            result2 = ibm_db.fetch_tuple(stmt2)
    # Report on extra DNs in first server
    while result1:
        count1 += 1
        dn_trunc1, modify_timestamp1 = result1[0], result1[1]
        write_to_csv(writer, dn1, None, dn_trunc1, current_timestamp, modify_timestamp1, None, '2')
        result1 = ibm_db.fetch_tuple(stmt1)
    # Report on extra DNs in second server
    while result2:
        count2 += 1
        dn_trunc2, modify_timestamp2 = result2[0], result2[1]
        write_to_csv(writer, dn2, None, dn_trunc2, current_timestamp, None, modify_timestamp2, '3')
        result2 = ibm_db.fetch_tuple(stmt2)
    print("Total Entries in {}: {}".format(hostname1, count1))
    print("Total Entries in {}: {}".format(hostname2, count2))


def get_connection(dbname, hostname, port, userid, password):
    conn_str = (
        "DATABASE={};"
        "HOSTNAME={};"
        "PORT={};"
        "PROTOCOL=TCPIP;"
        "UID={};"
        "PWD={};"
    ).format(dbname, hostname, port, userid, password)
    logger.debug("DB2 Connection: {}".format(conn_str))
    return ibm_db.pconnect(conn_str, "", "")


def get_arguments():
    """
    Get the command-line arguments
    """
    aparser = argparse.ArgumentParser(description='Provide DB2 connection details to compare LDAP server contents.')
    aparser.add_argument('--dbname1', help='DB2 Database Name underlying LDAP.', required=True)
    aparser.add_argument('--hostname1', help='Hostname of LDAP server (defaults to localhost).', default='localhost')
    aparser.add_argument('--port1', help='Port# DB2 is listening on (defaults to 50000).', default=50000)
    aparser.add_argument('--schema1', help='DB2 Table name schema (defaults to userid1).', required=False)
    aparser.add_argument('--userid1', help='Userid to connect to DB2 (defaults to dbname1).', required=False)
    aparser.add_argument('--password1', help='Password to connect to DB2.', required=True)
    aparser.add_argument('--dbname2', help='DB2 Database Name underlying LDAP (defaults to dbname1).', required=False)
    aparser.add_argument('--hostname2', help='Hostname of LDAP server (defaults to hostname1).', required=False)
    aparser.add_argument('--port2', help='Port# DB2 is listening on (defaults to port1).', required=False)
    aparser.add_argument('--schema2', help='DB2 Table name schema (defaults to schema1).', required=False)
    aparser.add_argument('--userid2', help='Userid to connect to DB2 (defaults to userid1).', required=False)
    aparser.add_argument('--password2', help='Password to connect to DB2 (defaults to password1).', required=False)
    aparser.add_argument('--loglevel', help='Logging Level (defaults to CRITICAL).', required=False, default='CRITICAL',
                         choices=['DEBUG', 'INFO', 'ERROR', 'CRITICAL'], type=str.upper)
    aparser.add_argument('--output_file', help='Output CSV of differences (defaults to stdout).', required=False)

    try:
        return aparser.parse_args()
    except IOError as msg:
        aparser.error(str(msg))


if __name__ == '__main__':
    try:
        starttime = datetime.utcnow()
        conn1, conn2, fout = None, None, None
        args = get_arguments()
        DEFAULT_LOGGING = {
            'version': 1,
            'disable_existing_loggers': False,
            'formatters': {
                'standard': {
                    'format': '[%(asctime)s] [PID:%(process)d TID:%(thread)d] [%(levelname)s] [%(name)s] [%(funcName)s():%(lineno)s] %(message)s'
                },
            },
            'handlers': {
                'default': {
                    'level': args.loglevel,
                    'formatter': 'standard',
                    'class': 'logging.StreamHandler',
                },
            },
            'loggers': {
                '': {
                    'level': args.loglevel,
                    'handlers': ['default'],
                    'propagate': True
                }
            }
        }
        logging.config.dictConfig(DEFAULT_LOGGING)
        logger.info("Start of Script: {}".format(starttime))
        # Get connection details to DB2 database underlying first LDAP server
        if args.userid1:
            userid1 = args.userid1
        else:
            userid1 = args.dbname1
        if args.schema1:
            schema1 = args.schema1
        else:
            schema1 = userid1
        conn1 = get_connection(args.dbname1, args.hostname1, args.port1, userid1, args.password1)

        # Get connection details to DB2 database underlying second LDAP server
        if args.dbname2:
            dbname2 = args.dbname2
        else:
            dbname2 = args.dbname1
        if args.hostname2:
            hostname2 = args.hostname2
        else:
            hostname2 = args.hostname1
        if args.port2:
            port2 = args.port2
        else:
            port2 = args.port1
        if args.userid2:
            userid2 = args.userid2
        else:
            userid2 = userid1
        if args.password2:
            password2 = args.password2
        else:
            password2 = args.password1
        if args.schema2:
            schema2 = args.schema2
        else:
            schema2 = schema1
        conn2 = get_connection(dbname2, hostname2, port2, userid2, password2)

        if args.output_file:
            fout = open(args.output_file, 'w')
        else:
            fout = sys.stdout
        print_legend(args.hostname1, hostname2)
        # Compare DNs/ModifyTimestamp from first and second LDAP servers
        compare_all_entry_modify_timestamps(args.hostname1, conn1, schema1, hostname2, conn2, schema2, fout)
        endtime = datetime.utcnow()
        logger.info("End of Script: {}".format(endtime))
        print("Script ran for: {}".format(endtime - starttime))
    except Exception as e:
        conn_error = ibm_db.conn_error()
        stmt_error = ibm_db.stmt_error()
        if conn_error != '':
            print("Error Code: {} Msg: {}".format(conn_error, ibm_db.conn_errormsg()))
            if conn1:
                print("Connection issue with server#2 most probably.")
            else:
                print("Connection issue with server#1 most probably.")
        elif stmt_error != '':
            print("Error Code: {} Msg: {}".format(stmt_error, ibm_db.stmt_errormsg()))
        raise e
    finally:
        if fout and fout is not sys.stdout:
            fout.close()
        if conn1:
            ibm_db.close(conn1)
        if conn2:
            ibm_db.close(conn2)
