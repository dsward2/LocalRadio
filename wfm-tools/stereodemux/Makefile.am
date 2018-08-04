bin_PROGRAMS = stereodemux
stereodemux_CPPFLAGS = -std=c++11 -Wall -Wextra -Wstrict-overflow -Wshadow \
												$(MACPORTS_CF) \
												-Wuninitialized -pedantic $(RFLAGS)
stereodemux_LDADD = $(MACPORTS_LD) -lc $(LIQUID) $(SNDFILE)
stereodemux_SOURCES = stereodemux.cc ../liquid_wrappers.cc
