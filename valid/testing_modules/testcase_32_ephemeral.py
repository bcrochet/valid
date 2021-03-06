from valid.valid_testcase import *


class testcase_32_ephemeral(ValidTestcase):
    """
    It should be possible to use ephemeral device (if we have one)
    """
    stages = ['stage1']
    tags = ['default']

    def test(self, connection, params):
        prod = params['product'].upper()
        ver = params['version'].upper()
        has_ephemeral = False
        for bdev in params['bmap']:
            if 'ephemeral_name' in bdev.keys():
                name = bdev['name']
                if (prod in ['RHEL', 'BETA']) and (ver.startswith('5.')):
                    if name.startswith('/dev/xvd'):
                        # no xvd* for RHEL5
                        continue
                elif (prod in ['RHEL', 'BETA']) and (ver.startswith('6.')):
                    if name.startswith('/dev/sd'):
                        name = '/dev/xvd' + name[7:]
                    if params['virtualization'] != 'hvm' and len(name) == 9 and ord(name[8]) < ord('w'):
                        # there is a 4-letter shift
                        name = name[:8] + chr(ord(name[8]) + 4)
                else:
                    # Fedora and newer RHELs
                    if name.startswith('/dev/sd'):
                        name = '/dev/xvd' + name[7:]
                has_ephemeral = True
                self.get_return_value(connection, 'fdisk -l %s | grep \'^Disk\'' % name, 30)
                if self.get_result(connection, 'grep \'%s \' /proc/mounts  | wc -l' % name, 5) == '0':
                    # device is not mounted, doing fs creation
                    if self.get_result(connection, 'ls -la /sbin/mkfs.vfat 2> /dev/null | wc -l', 5) == '1':
                        # mkfs.vfat is faster!
                        self.get_return_value(connection, 'mkfs.vfat -I %s' % name, 60)
                    else:
                        self.get_return_value(connection, 'mkfs.ext3 %s' % name, 300)
        if not has_ephemeral:
            self.log.append({
                    'result': 'skip',
                    'comment': 'no ephemeral devices in block map'
                    })
        return self.log
