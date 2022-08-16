proc snprintf*(ws: cstring, len: csize_t, format: cstring): cint {.importc, varargs, header: "<cstdio>".}
