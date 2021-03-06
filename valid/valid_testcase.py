import re
import logging
import threading
from patchwork.expect import *


class ValidTestcase(object):
    def __init__(self):
        self.log = []

    def ping_pong(self, connection, command, expectation, timeout=10):
        logging.debug(threading.currentThread().name + ": ping_pong '%s' expecting '%s'" % (command, expectation))
        result = {"command": command, "expectation": expectation}
        try:
            Expect.ping_pong(connection, command, expectation, timeout)
            result["result"] = "passed"
            logging.debug(threading.currentThread().name + ": ping_pong passed")
        except ExpectFailed, e:
            result["result"] = "failed"
            result["actual"] = e.message
            logging.debug(threading.currentThread().name + ": ping_pong failed: '%s'" % e.message)
        self.log.append(result)

    def match(self, connection, command, regexp, grouplist=[1], timeout=10):
        try:
            logging.debug(threading.currentThread().name + ": matching '%s' against '%s'" % (command, regexp.pattern))
            Expect.enter(connection, command)
            result = Expect.match(connection, regexp, grouplist, timeout)
            self.log.append({"result": "passed", "match": regexp.pattern, "command": command, "value": str(result)})
            logging.debug(threading.currentThread().name + ": matched '%s'" % result)
            return result
        except ExpectFailed, e:
            self.log.append({"result": "failed", "match": regexp.pattern, "command": command, "actual": e.message})
            logging.debug(threading.currentThread().name + ": match failed '%s'" % e.message)
            return None

    def get_result(self, connection, command, timeout=10):
        try:
            logging.debug(threading.currentThread().name + ": getting result for '%s'" % command)
            Expect.enter(connection, "echo '###START###'; " + command + "; echo '###END###'")
            regexp = re.compile(".*\r\n###START###\r\n(.*)\r\n###END###\r\n.*", re.DOTALL)
            result = Expect.match(connection, regexp, [1], timeout)
            self.log.append({"result": "passed", "command": command, "value": result[0]})
            logging.debug(threading.currentThread().name + ": got result: '%s'" % result[0])
            return result[0]
        except ExpectFailed, e:
            self.log.append({"result": "failed", "command": command, "actual": e.message})
            logging.debug(threading.currentThread().name + ": getting failed: '%s'" % e.message)
            return None

    def get_return_value(self, connection, command, timeout=15, expected_status=0, nolog=False):
        logging.debug(threading.currentThread().name + ": getting return value '%s'" % command)
        status = connection.recv_exit_status(command + " >/dev/null 2>&1", timeout)
        if not nolog:
            if status == expected_status:
                self.log.append({"result": "passed", "command": command})
            else:
                self.log.append({"result": "failed", "command": command, "actual": str(status)})
        logging.debug(threading.currentThread().name + ": got '%s' status" % status)
        return status
