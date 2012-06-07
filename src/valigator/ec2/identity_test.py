from valigator.ec2.test import Test
from valigator.factories import Factory as baseFactory
from valigator.result import SimpleResult, SimpleCommandResult, CastedSimpleCommandResult
from zope.interface import implements
from valigator.ec2.interfaces import IInstanceSwitch
from valigator.interfaces import IFromString
from instance import JsonInstance


class ExpectedResult(SimpleResult):
	implements(IInstanceSwitch)
	def instance_switch(self, instance):
		self.value = instance


class ActualResult(CastedSimpleCommandResult):
	implements(IInstanceSwitch)
	value_type = JsonInstance
	command = 'wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document'
	def instance_switch(self, instance):
		# the json stuff contains a version string of a different meaning
		# just copy over instance's version for the comparison not to fail
		self.value.version = instance.version
		# the same holds for following attributes
		self.value.hostname = instance.hostname
		self.value.key_file = instance.key_file
		self.value.username = instance.username


class IdentityTestFactory(baseFactory):
	def get_test(self):
		test= Test()
		test.name = 'ec2.IdentityTest'
		test.expected_result = ExpectedResult()
		test.actual_result = ActualResult()
		return test


class SignatureTestFactory(baseFactory):
	def get_test(self):
		test = Test()
		test.name = 'ec2.SignatureTest'
		test.expected_result = SimpleResult()
		test.expected_result.value = ''
		test.actual_result = SimpleCommandResult()
		from ..value import REValue
		revalue = REValue()
		import re
		expression = re.compile('.+')
		revalue.expression = expression
		test.expected_result.value = revalue
		test.actual_result.command = 'wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/signature'
		return test
