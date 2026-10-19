"""Exercise the curl-pipe entry point with a real controlling terminal and fake tools."""
import errno
import json
import os
import pty
import select
import sys
import time

source, response = sys.argv[1:3]
read_fd, write_fd = os.pipe()
pid, master = pty.fork()
if pid == 0:
    os.close(write_fd)
    os.dup2(read_fd, 0)
    os.close(read_fd)
    os.execv('/bin/sh', ['sh'])

os.close(read_fd)
with open(source, 'rb') as script:
    data = script.read()
while data:
    data = data[os.write(write_fd, data):]
os.close(write_fd)
output = bytearray()
answered = False
deadline = time.monotonic() + 12
status = None
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master], [], [], 0.1)
        if ready:
            try:
                chunk = os.read(master, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            output.extend(chunk)
            if not answered and b'Open Usage Desk now? [Y/n]' in output:
                os.write(master, b'\x04' if response == 'eof' else (response + '\n').encode())
                answered = True
        if status is None:
            ended, result = os.waitpid(pid, os.WNOHANG)
            if ended:
                status = result
    else:
        os.kill(pid, 9)
        raise RuntimeError('Installer terminal flow timed out')
finally:
    if status is None:
        _, status = os.waitpid(pid, 0)
    os.close(master)
print(json.dumps({'status': os.waitstatus_to_exitcode(status), 'stdout': output.decode(), 'stderr': '', 'answered': answered}))
