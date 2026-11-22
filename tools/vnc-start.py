import sys
import time
from vncdotool import api

HOST = sys.argv[1] if len(sys.argv) > 1 else '172.20.48.1::5901'
PASSWD = sys.argv[2] if len(sys.argv) > 2 else 'labvnc'
shot = sys.argv[3] if len(sys.argv) > 3 else '/mnt/d/MIDAS/research/java4shell-lab/vnc3.png'

c = api.connect(HOST, password=PASSWD)
c.mouseMove(25, 718)
c.mousePress(1)
time.sleep(2)
c.captureScreen(shot)
c.disconnect()
print('done')
