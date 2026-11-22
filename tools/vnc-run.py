import sys
import time
from vncdotool import api

HOST = sys.argv[1] if len(sys.argv) > 1 else '172.20.48.1::5901'
PASSWD = sys.argv[2] if len(sys.argv) > 2 else 'labvnc'
command = sys.argv[3] if len(sys.argv) > 3 else r'cmd /c ipconfig /all > "\\vmware-host\shared folders\java4shell-lab\guest-ip.txt"'
shot = sys.argv[4] if len(sys.argv) > 4 else '/mnt/d/MIDAS/research/java4shell-lab/vnc4.png'


def type_text(client, text, delay=0.015):
    for ch in text:
        client.keyPress(ch)
        time.sleep(delay)


c = api.connect(HOST, password=PASSWD)
c.keyPress('lsuper-r')
time.sleep(1.5)
type_text(c, command)
time.sleep(0.5)
c.keyPress('enter')
time.sleep(4)
c.captureScreen(shot)
c.disconnect()
print('done')
