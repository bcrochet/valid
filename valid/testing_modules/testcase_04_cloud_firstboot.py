from valid.valid_testcase import *


class testcase_04_cloud_firstboot(ValidTestcase):
    stages = ["stage1"]
    not_applicable = {"product": "(?i)Fedora"}

    def test(self, connection, params):
        if (params["product"].upper() == "RHEL" or params["product"].upper() == "BETA") and params["version"].startswith("6.0"):
            self.log.append({"result": "passed", "comment": "waived test for bugzilla 704821"})
        else:
            self.ping_pong(connection, "chkconfig --list rh-cloud-firstboot", "3:off")
            self.get_return_value(connection, "test -f /etc/sysconfig/rh-cloud-firstboot")
            self.ping_pong(connection, "cat /etc/sysconfig/rh-cloud-firstboot", "RUN_FIRSTBOOT=NO")
        return self.log
