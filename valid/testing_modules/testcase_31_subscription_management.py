from valid.valid_testcase import *

class testcase_31_subscription_management(ValidTestcase):
    stages = ["stage1"]
    applicable = {"product": "(?i)RHEL|BETA", "version": "^5\.[12345678]$|^6\.[123]$"}

    def test(self, connection, params):
        # check subscription-manager plugin is disabled
        self.ping_pong(
            connection,
            'yum --disablerepo="*" -v repolist',
            expectation='Not loading "subscription-manager" plugin',
            timeout=30
        )
        # check subscription-manager plugin can be enabled
        self.ping_pong(
            connection,
            'yum --enableplugin=subscription-manager --disablerepo="*" -v repolist',
            expectation='Loading "subscription-manager" plugin',
            timeout=30
        )
        # check system isn't subscribbed
        self.ping_pong(
            connection,
            'subscription-manager list',
            expectation='No installed products to list',
            timeout=90
        )
        return self.log
