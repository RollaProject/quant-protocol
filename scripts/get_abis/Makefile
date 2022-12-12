CC=gcc
CXX=g++
RM=rm -f
CXXFLAGS=-std=c++20 -Werror -Wall -Wextra -pedantic -Ofast

SRCS=get_abis.cpp simdjson.cpp
OBJS=$(subst .cpp,.o,$(SRCS))

all: get_abis

get_abis: $(OBJS)
	$(CXX) -o get_abis $(OBJS)

simdjson.cpp:
	touch $@

depend: .depend

.depend: $(SRCS)
	$(RM) ./.depend
	curl -O https://raw.githubusercontent.com/simdjson/simdjson/master/singleheader/simdjson.h -O https://raw.githubusercontent.com/simdjson/simdjson/master/singleheader/simdjson.cpp
	$(CXX) $(CXXFLAGS) -MM $^>>./.depend;

clean:
	$(RM) $(OBJS)
	$(RM) simdjson.h simdjson.cpp

distclean: clean
	$(RM) *~ .depend

include .depend
