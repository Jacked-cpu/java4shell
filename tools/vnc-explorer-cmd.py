import sys
import time
from vncdotool import api

HOST = sys.argv[1] if len(sys.argv) > 1 else '172.20.48.1::5901'
PASSWD = sys.argv[2] if len(sys.argv) > 2 else 'labvnc'
shot = sys.argv[3] if len(sys.argv) > 3 else '/mnt/d/MIDAS/research/java4shell-lab/vnc7.png'

command = r'ipconfig /all > "\\vmware-host\shared folders\java4shell-lab\guest-ip.txt"'


def type_text(client, text, delay=0.03):
    for ch in text:
        client.keyPress(ch)
        time.sleep(delay)


c = api.connect(HOST, password=PASSWD)

c.mouseMove(450, 238)
c.mousePress(1)
time.sleep(0.8)
for _ in range(40):
    c.keyPress('backspace')
    time.sleep(0.01)
type_text(c, 'cmd')
time.sleep(0.3)
c.keyPress('enter')
time.sleep(3)
type_text(c, command)
time.sleep(0.5)
c.keyPress('enter')
time.sleep(4)
c.captureScreen(shot)
c.disconnect()
print('done')
