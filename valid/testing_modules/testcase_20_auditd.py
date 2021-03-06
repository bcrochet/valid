from valid.valid_testcase import *


class testcase_20_auditd(ValidTestcase):
    """
    Check auditd:
    - service should be on
    - config files shoud have specified checksums
    """
    stages = ['stage1']
    applicable = {'product': '(?i)RHEL|BETA', 'version': '5.*|6.*'}
    tags = ['default']

    def test(self, connection, params):
        if params['version'].startswith('6.'):
            self.ping_pong(connection, 'md5sum /etc/audit/auditd.conf | cut -f 1 -d \' \'', 'e1886162554c18906df2ecd258aa4794')
            self.ping_pong(connection, 'md5sum /etc/sysconfig/auditd  | cut -f 1 -d \' \'', 'd4d43637708e30418c30003e212f76fc')
            self.ping_pong(connection, 'chkconfig --list auditd', '3:on.*5:on')
        elif params['version'].startswith('5.'):
            self.ping_pong(connection, 'md5sum /etc/audit/auditd.conf | cut -f 1 -d \' \'', '612ddf28c3916530d47ef56a1b1ed1ed')
            self.ping_pong(connection, 'md5sum /etc/sysconfig/auditd  | cut -f 1 -d \' \'', '123beb3a97a32d96eba4f11509e39da2')
        self.ping_pong(connection, 'md5sum /etc/audit/audit.rules | cut -f 1 -d \' \'', 'f9869e1191838c461f5b9051c78a638d')
        self.ping_pong(connection, 'chkconfig --list auditd', '3:on.*5:on')
        return self.log
