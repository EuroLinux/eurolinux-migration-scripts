#!/usr/bin/env python2
'''
Red Hat satellite 5.x script for unregister system(s)
'''

import argparse
import xmlrpclib
import socket
from sys import stderr, exit, argv

SAT_URL = 'https://xmlrpc.elupdate.euro-linux.com/rpc/api'


def connect(username, password, VERBOSE_LEVEL=0):
    print 'Attempting to connect to {0}'.format(SAT_URL)

    # Open connection to XML RPC server
    client = xmlrpclib.Server(SAT_URL, verbose=VERBOSE_LEVEL)
    try:
        key = client.auth.login(username, password)
        stderr.write('Login succeeded\n')
    except xmlrpclib.Fault as err:
        stderr.write('Failed Login')
        stderr.write('ERROR code: {0}'.format(err.faultCode))
        stderr.write('Message: {0}'.format(err.faultString))
        exit(1)
    except socket.error as (err, errstr):
        stderr.write('ERROR Code: {0}\tString: {1}\n'.format(err, errstr))
        exit(1)

    return (client, key)


# Parsing args
parser = argparse.ArgumentParser()
parser.add_argument("-u", "--user", help='Sat user', required=True)
parser.add_argument("-p", "--password", help='Sat pass', required=True)
parser.add_argument("-i", "--ids", help='System id[s]', required=True, nargs='+', type=int)
args = parser.parse_args(argv[1:])
print args
# Connecting to satellite
client, key = connect(args.user, args.password)

# Removing systems
for id in args.ids:
    try:
        status = client.system.deleteSystem(key, id)
        if status == 1:
            print 'System with id {0} unregistered successful'.format(id)
    except Exception as e:
        print "There was ERROR with id {0}".format(id)
        print e

client.auth.logout(key)