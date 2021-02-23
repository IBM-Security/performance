import base64
import asn1
import ibm_db
from datetime import datetime
import argparse
import logging.config
import logging
import csv
import sys
import distutils.util

logger = logging.getLogger(__name__)


def find_modifytimestamp(input_stream):
    """Look for modifyTimestamp"""
    while not input_stream.eof():
        tag = input_stream.peek()
        if tag.typ == asn1.Types.Primitive:
            tag, value = input_stream.read()
            if value == b'modifyTimestamp':
                input_stream.enter()
                tag, value = input_stream.read()
                return value.decode('ascii')
        elif tag.typ == asn1.Types.Constructed:
            input_stream.enter()
            timestamp = find_modifytimestamp(input_stream)
            if timestamp:
                return timestamp
            input_stream.leave()
    return None


def decode_and_find_modifytimestamp(base64_message):
    base64_bytes = base64_message.encode('ascii')
    logger.debug("Decoding: {}".format(base64_bytes))
    message_bytes = base64.b64decode(base64_bytes)
    decoder = asn1.Decoder()
    decoder.start(message_bytes)
    return find_modifytimestamp(decoder)


def get_latest_update(conn, schema, tablename):
    try:
        sql = "select max(id) from {}.{}".format(schema, tablename)
        logger.debug("Executing SQL: {}".format(sql))
        stmt = ibm_db.exec_immediate(conn, sql)
        result = ibm_db.fetch_tuple(stmt)
        if result:
            return result[0]
        else:
            return 0
    except Exception as e:
        if "SQL0204N" in ibm_db.stmt_errormsg():
            logger.debug("{}.{} was missing, returning -1 for max(id)".format(schema, tablename))
            return -1
        else:
            raise e


def get_changes(conn, schema, tablename, changeid):
    '''
    Execute a query to get the replication status for a given suffix (needs corresponding EID)
    '''
    try:
        ret_data = []
        sql = (
            "select dn_trunc, control_long, lastchangeid"
            " from {}.LDAP_ENTRY as l, {}.REPLSTATUS as r, {}.{} as rc"
            " where r.LASTCHANGEID+{}=rc.id"
            " and l.eid=r.eid"
        ).format(schema, schema, schema, tablename, changeid)
        logger.debug("Executing SQL: {}".format(sql))
        stmt = ibm_db.exec_immediate(conn, sql)
        result = ibm_db.fetch_tuple(stmt)
        while result:
            consumerDN, controlString, lastChangeID = result[0], result[1], result[2]
            logger.debug("consumerDN: {} controlString: {} lastChangeID: {}".
                         format(consumerDN, controlString, lastChangeID))
            controlComponents = controlString.split('control: 1.3.18.0.2.10.19 false:: ')
            if len(controlComponents) > 1:
                control = controlComponents[1].replace('\n ', '')
                timestamp = decode_and_find_modifytimestamp(control)
                modifytimestamp = datetime.strptime(timestamp, "%Y%m%d%H%M%S.%fZ")
                age = datetime.utcnow() - modifytimestamp
                consumerComponents = consumerDN.split(',')
                consumer = consumerComponents[0].split('=')[1]
                ret_data.append([consumer, modifytimestamp, age, lastChangeID])
            else:
                logger.info("No data found!")
            result = ibm_db.fetch_tuple(stmt)
        return ret_data
    except Exception as e:
        if "SQL0204N" in ibm_db.stmt_errormsg():
            return ret_data
        else:
            raise e


def print_legend(csvFile, outputcsv):
    """
    Print a legend describing what the CSV output looks like.
    """
    if outputcsv:
        print("Legend for output:")
        print("  context - suffix or context present in server (may or may not be replicated).")
        print("  consumer - hostname or ip address of server data is being replicated to.")
        print("  successfulTimestamp - last successful change that was replicated.")
        print("  pendingTimestamp - last pending change that needs to be replicated.")
        print("  queueSize - number of objects pending in replication queue.")
        print("")
        print("Note: Timestamps are provided in UTC timezone.")
        print("")
        writer = csv.DictWriter(csvFile,
                                ['context', 'consumer', 'successfulTimestamp', 'pendingTimestamp', 'queueSize'])
        writer.writeheader()
        return writer
    else:
        print('Reporting last successful change / oldest pending changes for all contexts')
        print('--------------------------------------------------------------------------')
        return None


def write_or_print_data(csvWriter, context, ret_data1, maxChangeID, ret_data2, outputcsv):
    if not outputcsv:
        print('\n{} replication status:'.format(context))
    if ret_data1:
        for rd1 in ret_data1:
            pendingTimestamp, age, queueSize = None, None, None
            for rd2 in ret_data2:
                if rd1[0] == rd2[0]:
                    pendingTimestamp = rd2[1]
                    age = rd2[2]
                    queueSize = maxChangeID - rd2[3]
                    break
            if outputcsv:
                csvWriter.writerow({
                    'context': context,
                    'consumer': rd1[0],
                    'successfulTimestamp': rd1[1],
                    'pendingTimestamp': pendingTimestamp,
                    'queueSize': queueSize
                })
            else:
                print("  {} last successful change's modifyTimestamp age is {}".format(rd1[0], rd1[2]))
                if age:
                    print("  {} oldest pending change's modifyTimestamp age is {} (queue size: {})".
                          format(rd1[0], age, queueSize))
                else:
                    print("  Congratulations! No pending replication entries found.")
    else:
        logger.info("Data indicates this suffix is not replicated: {}".format(context))
        if not outputcsv:
            print("  No replication data found.")


def report_changes_for_contexts(schema, csvFile, outputcsv):
    writer = print_legend(csvFile, outputcsv)
    # Execute query to find all suffixes being replicated
    sql = (
        "select eid, dn_trunc "
        "from {}.ldap_entry "
        "where eid in "
        "(select peid "
        "from {}.ldap_entry as l, {}.OBJECTCLASS as o "
        "where l.eid=o.eid "
        "and o.OBJECTCLASS='IBM-REPLICAGROUP')"
    ).format(schema, schema, schema)
    logger.debug("Executing SQL: {}".format(sql))
    stmt = ibm_db.exec_immediate(conn, sql)
    result = ibm_db.fetch_tuple(stmt)
    while (result):
        eid, context = result[0], result[1]
        logger.debug("eid: {} context: {}".format(eid, format))
        tablename = "REPLCHG{}".format(eid)
        ret_data1 = get_changes(conn, schema, tablename, 0)  # Successful changes
        if not ret_data1:
            logger.info("No replication data found for successful changes, perhaps no replication setup for {}?"
                        .format(context))
            write_or_print_data(writer, context, None, None, None, outputcsv)
        else:
            maxChangeID = get_latest_update(conn, schema, tablename)
            ret_data2 = get_changes(conn, schema, tablename, 1)  # Oldest Pending changes
            write_or_print_data(writer, context, ret_data1, maxChangeID, ret_data2, outputcsv)
        result = ibm_db.fetch_tuple(stmt)


def get_arguments():
    """
    Get the command-line arguments
    """
    aparser = argparse.ArgumentParser(description='Provide DB2 connection details to determine replication status.')
    aparser.add_argument('--dbname', help='DB2 Database Name underlying LDAP.', required=True)
    aparser.add_argument('--hostname', help='Hostname of LDAP server (defaults to localhost).', default='localhost')
    aparser.add_argument('--port', help='Port# DB2 is listening on (defaults to 50000).', default=50000)
    aparser.add_argument('--schema', help='DB2 Table name schema (defaults to userid).', required=False)
    aparser.add_argument('--userid', help='Userid to connect to DB2 (defaults to dbname).', required=False)
    aparser.add_argument('--password', help='Password to connect to DB2.', required=True)
    aparser.add_argument('--loglevel', help='Logging Level (defaults to CRITICAL).', required=False, default='CRITICAL',
                         choices=['DEBUG', 'INFO', 'ERROR', 'CRITICAL'], type=str.upper)
    aparser.add_argument('--outputcsv', help='Test output or CSV format (defaults to False).', required=False,
                         default='false', choices=['true', 'y', 'yes', '1', 'on', 'false', 'n', 'no', '0', 'off'],
                         type=str.lower)
    aparser.add_argument('--output_file', help='Output CSV of differences (defaults to stdout).', required=False)

    try:
        return aparser.parse_args()
    except IOError as msg:
        aparser.error(str(msg))


if __name__ == '__main__':
    try:
        starttime = datetime.utcnow()
        conn, fout = None, None
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

        # Get connection details to DB2 database underlying the LDAP server
        if args.userid:
            userid = args.userid
        else:
            userid = args.dbname
        if args.schema:
            schema = args.schema
        else:
            schema = userid
        conn_str = (
            "DATABASE={};"
            "HOSTNAME={};"
            "PORT={};"
            "PROTOCOL=TCPIP;"
            "UID={};"
            "PWD={};"
        ).format(args.dbname, args.hostname, args.port, userid, args.password)
        logger.debug("DB2 Connection: {}".format(conn_str))
        conn = ibm_db.pconnect(conn_str, "", "")
        if args.output_file:
            fout = open(args.output_file, 'w')
        else:
            fout = sys.stdout
        outputcsv = bool(distutils.util.strtobool(args.outputcsv))
        report_changes_for_contexts(schema, fout, outputcsv)
        endtime = datetime.utcnow()
        logger.info("End of Script: {}".format(endtime))
        print("Script ran for: {}".format(endtime - starttime))
    except Exception as e:
        conn_error = ibm_db.conn_error()
        stmt_error = ibm_db.stmt_error()
        if conn_error != '':
            print("Error Code: {} Msg: {}".format(conn_error, ibm_db.conn_errormsg()))
        elif stmt_error != '':
            print("Error Code: {} Msg: {}".format(stmt_error, ibm_db.stmt_errormsg()))
        raise e
    finally:
        if fout and fout is not sys.stdout:
            fout.close()
        if conn:
            ibm_db.close(conn)
