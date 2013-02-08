from valid.valid_testcase import *


class testcase_34_cpu(ValidTestcase):
    stages = ["stage1"]

    def test(self, connection, params):
        if "cpu" in params.keys():
            self.ping_pong(connection, "cat /proc/cpuinfo | grep '^processor' | wc -l", params["cpu"])
        else:
            self.log.append({
                    "result": "skip",
                    "comment": "cpu in hwp is not set"
                    })
        return self.log