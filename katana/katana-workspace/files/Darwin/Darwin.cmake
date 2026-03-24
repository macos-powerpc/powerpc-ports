SET(LIBKSYSGUARDD_SOURCES
    Darwin/CPU.c
    Darwin/loadavg.c
    Darwin/Memory.c
    Darwin/ProcessList.c
    Darwin/netdev.c
    Darwin/logfile.c
)

# macOS requires CoreFoundation and IOKit frameworks
SET(LIBKSYSGUARDD_LIBS "-framework CoreFoundation -framework IOKit")
