import ctypes
import os
import sys
libc = ctypes.CDLL(None, use_errno=True)
source, destination = map(os.fsencode, sys.argv[1:])
if sys.platform == "darwin":
    rename = libc.renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    result = rename(source, destination, 4)
else:
    rename = libc.renameat2
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    result = rename(-100, source, -100, destination, 1)
if result != 0:
    error = ctypes.get_errno()
    raise OSError(error, "Config publication refused: " + os.strerror(error))
